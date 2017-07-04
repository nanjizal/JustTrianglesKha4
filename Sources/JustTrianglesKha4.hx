package;

// References
// http://luboslenco.com/kha3d/ see example 6.
// https://github.com/RafaelOliveira/BasicKha
// polyk.ivank.net

import kha.Color;
import kha.graphics4.VertexStructure;
import kha.graphics4.VertexBuffer;
import kha.graphics4.IndexBuffer;
import kha.graphics4.FragmentShader;
import kha.graphics4.VertexShader;
import kha.graphics4.VertexData;
import kha.graphics4.Usage;
import kha.graphics4.ConstantLocation;
import kha.graphics4.CompareMode;
//import kha.graphics2.ImageScaleQuality;
import kha.graphics2.Graphics;
import kha.graphics4.TextureFormat;
//import kha.math.Matrix4;
import kha.math.FastMatrix4;
import kha.math.FastVector3;
import kha.graphics4.PipelineState;
import kha.Shaders;
import kha.Assets;
import kha.Framebuffer;
import kha.Image;
import kha.input.Keyboard;
import kha.input.Mouse;
import kha.input.KeyCode;
import kha.Scaler;
import kha.System;
import kha.graphics4.DepthStencilFormat;  


import org.poly2tri.VisiblePolygon;
import me.nerik.poly2trihx.TestPoints;

import justTriangles.Triangle;
import justTriangles.Draw;
import justTriangles.Point;
import justTriangles.PolyK;
import justTriangles.PathContext;
import justTriangles.ShapePoints;
import justTriangles.QuickPaths;
import justTriangles.SvgPath;
import justTriangles.PathContextTrace;
import DroidSans;

using justTriangles.QuickPaths;
@:enum
    abstract RainbowColors( Int ){
        var Violet = 0x9400D3;
        var Indigo = 0x4b0082;
        var Blue   = 0x0000FF;
        var Green  = 0x00ff00;
        var Yellow = 0xFFFF00;
        var Orange = 0xFF7F00;
        var Red    = 0xFF0000;
        var Black  = 0x000000;
    }
class JustTrianglesKha4 {
    var rainbow = [ Black, Red, Orange, Yellow, Green, Blue, Indigo, Violet ]; 
    var pixelLayer: Image;
    var vectorLayer: Image;
    var initialized: Bool = false;
    var ball: Image;
    var xPos: Float;
    var yPos: Float;
    var keys: Array<Bool> = [for(i in 0...4) false];
    
    public function new(){
        pixelLayer = Image.createRenderTarget(1280, 720);
        vectorLayer = Image.createRenderTarget(1280, 720, TextureFormat.RGBA32, DepthStencilFormat.DepthOnly, 4 );
        Keyboard.get().notify(keyDown, keyUp);
        var mouse = Mouse.get();
        mouse.notify(null, null, mouseMove, null);
        Assets.loadEverything( loadingFinished );
    }

    // An array of vertices to form a cube
    static var vertices:Array<Float> = [];
    // Array of colors for each cube vertex
    static var colors:Array<Float> = [];
    var pipeline:PipelineState;
    var vertexBuffer:VertexBuffer;
    var indexBuffer:IndexBuffer;
    var mvp:FastMatrix4;
    var mvpID:ConstantLocation;
    var z: Float = -1;
    var structureLength = 6;
    
    public function setup3d():Void {
        // Define vertex structure
        var structure = new VertexStructure();
        structure.add( "pos", VertexData.Float3 );
        structure.add( "col", VertexData.Float3 );
        // Save length - we store position and color data
        

        // Compile pipeline state
        // Shaders are located in 'Sources/Shaders' directory
        // and Kha includes them automatically
        pipeline = new PipelineState();
        pipeline.inputLayout = [structure];
        pipeline.fragmentShader = Shaders.simple_frag;
        pipeline.vertexShader = Shaders.simple_vert;
        // Set depth mode
        pipeline.depthWrite = false;
        pipeline.depthMode = CompareMode.Less;
        pipeline.compile();
        
        // Get a handle for our "MVP" uniform
        mvpID = pipeline.getConstantLocation("MVP");

        // Projection matrix: 45° Field of View, 4:3 ratio, display range : 0.1 unit <-> 100 units
        var projection = FastMatrix4.perspectiveProjection(45.0, 16.0 / 9.0, 0.1, 100.0);
        // Or, for an ortho camera
        //var projection = FastMatrix4.orthogonalProjection(-10.0, 10.0, -10.0, 10.0, 0.0, 100.0); // In world coordinates
        
        // Camera matrix
        var view = FastMatrix4.lookAt(new FastVector3(0, 0, 10), // Camera is at (4, 3, 3), in World Space
                                  new FastVector3(0, 0, 0), // and looks at the origin
                                  new FastVector3(0, 1, 0) // Head is up (set to (0, -1, 0) to look upside-down)
        );

        // Model matrix: an identity matrix (model will be at the origin)
        var model = FastMatrix4.identity();
        // Our ModelViewProjection: multiplication of our 3 matrices
        // Remember, matrix multiplication is the other way around
        mvp = FastMatrix4.identity();
        mvp = mvp.multmat(projection);
        mvp = mvp.multmat(view);
        mvp = mvp.multmat(model);
        
        // vertexBufferLen = Std.int(vertices.length / 3)
        // Create vertex buffer
        vertexBuffer = new VertexBuffer(
            300000, // Vertex count - 3 floats per vertex
            structure, // Vertex structure
            Usage.DynamicUsage // Vertex data will stay the same
        );
        // indicesLen = indices.length;
        // Create index buffer
        indexBuffer = new IndexBuffer(
            300000  , // Number of indices for our cube
            Usage.DynamicUsage // Index data will stay the same
        );
    }
    
    public function updateVectors():Void {
     // Copy vertices and colors to vertex buffer
        var vbData = vertexBuffer.lock();
        for (i in 0...Std.int(vbData.length / structureLength)) {
            vbData.set( i * structureLength, vertices[i * 3] );
            vbData.set( i * structureLength + 1, vertices[i * 3 + 1] );
            vbData.set( i * structureLength + 2, vertices[i * 3 + 2] );
            vbData.set( i * structureLength + 3, colors[i * 3] );
            vbData.set( i * structureLength + 4, colors[i * 3 + 1] );
            vbData.set( i * structureLength + 5, colors[i * 3 + 2] );
        }
        vertexBuffer.unlock();
        // A 'trick' to create indices for a non-indexed vertex data
        var indices:Array<Int> = [];
        for (i in 0...Std.int(vertices.length / 3)) {
            indices.push(i);
        }
        // Copy indices to index buffer
        var iData = indexBuffer.lock();
        for (i in 0...iData.length) {
            iData[i] = indices[i];
        }
        indexBuffer.unlock();
    }
    
    var timeSlice: Float = 0;
    
    public function poly2TriTest(){
        var vp = new VisiblePolygon();
        vp.addPolyline( TestPoints.HAXE_LOGO );
        vp.addPolyline( TestPoints.HAXE_LOGO_HOLE );
        vp.performTriangulationOnce();
        var pt = vp.getVerticesAndTriangles();
        var tri = pt.triangles;
        var vert = pt.vertices;
        var triples = new ArrayTriple( tri );
        var a: Point;
        var b: Point;
        var c: Point;
        var i: Int;
        
        for( tri in triples ){
            i = Std.int( tri.a*3 );
            a = { x: vert[ i ]/500-1, y: vert[ i + 1 ]/500- 0.75 };
            //trace( 'a ' + a );
            i = Std.int( tri.b*3 );
            b = { x: vert[ i ]/500-1, y: vert[ i + 1 ]/500- 0.75 };
            //trace( 'b ' + b );
            i = Std.int( tri.c*3 );
            c = { x: vert[ i ]/500-1, y: vert[ i + 1 ]/500-0.75 };
            //trace( 'c ' + c );
            Draw.drawTri( 10, true, a, b, c, 3 );
        }
    }
    
    
    public function polykTest(){
        z = 0;
        var poly = [ 93., 195., 129., 92., 280., 81., 402., 134., 477., 70., 619., 61., 759., 97., 758., 247., 662., 347., 665., 230., 721., 140., 607., 117., 472., 171., 580., 178., 603., 257., 605., 377., 690., 404., 787., 328., 786., 480., 617., 510., 611., 439., 544., 400., 529., 291., 509., 218., 400., 358., 489., 402., 425., 479., 268., 464., 341., 338., 393., 427., 373., 284., 429., 197., 301., 150., 296., 245., 252., 384., 118., 360., 190., 272., 244., 165., 81., 259., 40., 216.];
        var polyPairs = new ArrayPairs( poly );
        var polySin = new Array<Float>();
        for( pair in polyPairs ){
            polySin.push( pair.x/500 );//+ 2*Math.sin( timeSlice*(Math.PI/180 ) ));
            polySin.push( pair.y/500 + 0.1*Math.sin( timeSlice*(Math.PI/180 )) + 0.4 );
        }
        timeSlice += 3;
        poly = polySin;
        var tgs = PolyK.triangulate( poly ); 
        var triples = new ArrayTriple( tgs );
        var a: Point;
        var b: Point;
        var c: Point;
        var i: Int;
        for( tri in triples ){
            i = Std.int( tri.a*2 );
            a = { x: poly[ i ], y: poly[ i + 1 ] };
            i = Std.int( tri.b*2 );
            b = { x: poly[ i ], y: poly[ i + 1 ] };
            i = Std.int( tri.c*2 );
            c = { x: poly[ i ], y: poly[ i + 1 ] };
            Draw.drawTri( 10, true, a, b, c, 6 );
        }
    }
    
    private function graphicsTests(){
        Draw.drawTri = Triangle.drawTri;
        var thick = 4;
        var ctx = new PathContext( 1, 500, 0, 100 );
        ctx.setColor( 2, 2 );
        ctx.setThickness( thick );
        ctx.lineType = TriangleJoinCurve; // - default
        var pathTrace = new PathContextTrace();
        var p = new SvgPath( ctx );
        p.parse( bird_d, 0, 0 );
        ctx.render( thick, false );
        ctx.setColor( 5, 5 );
        ctx.setThickness( 4 ); 
        var ctx2 = new PathContext( 1, 500, 0, 0 );
        ctx2.lineType = TriangleJoinCurve; // - default
        ctx2.setColor( 5, 5 );
        ctx2.setThickness( 4 ); 
        var p2 = new SvgPath( ctx2 );
        var c: Int ;
        var pos = 0;
        var str = "Kha";
        var letterPath: String;
        var glyph: Glyph;
        var letterScale = 0.05;
        var deltaX: Float = 600;
        var deltaY: Float = 150;
        var count = 0;
        while( true ){
            c = StringTools.fastCodeAt( str, pos++ );
            if( c == null ) {
                break;
            } else {
                glyph = DroidSans.getSymbol( c );
                if( glyph == null ) break;
                letterPath = glyph.d;
                deltaX += (glyph.ax)*letterScale;
                count++;
                if( letterPath == null ) break;
                p2.parse( letterPath, deltaX, deltaY, letterScale, -letterScale );
            }
        }
        ctx2.speechBubble( 3.5, 3.5, 500, -100 );
        ctx2.render( thick, false );
    }
    public static inline function toRGB( int: Int ) : { r: Float, g: Float, b: Float } {
        return {
            r: ((int >> 16) & 255) / 255,
            g: ((int >> 8) & 255) / 255,
            b: (int & 255) / 255,
        }
    }
    private function loadingFinished():Void{
        setup3d();
        initialized = true;
        ball = Assets.images.ball;
        xPos = (System.windowWidth() / 2) - (ball.width / 2);
        yPos = (System.windowHeight() / 2) - (ball.width / 2);
    }
    
    public function keyDown(keyCode:Int):Void{
        switch(keyCode){
            case KeyCode.Left:  
                keys[0] = true;
            case KeyCode.Right: 
                keys[1] = true;
            case KeyCode.Up:    
                keys[2] = true;
            case KeyCode.Down:  
                keys[3] = true;
            default: 
                
        }
    }
    public function keyUp(keyCode:Int  ):Void{ 
        switch(keyCode){
            case KeyCode.Left:  
                keys[0] = false;
            case KeyCode.Right: 
                keys[1] = false;
            case KeyCode.Up:    
                keys[2] = false;
            case KeyCode.Down:  
                keys[3] = false;
            default: 
                
        }
    }
    function mouseMove(x:Int, y:Int, movementX:Int, movementY:Int):Void{
        xPos = x - (ball.width / 2);
        yPos = y - (ball.height / 2);
    }
    public function update(): Void {
        if (!initialized)
            return;
        if (keys[0])
            xPos -= 3;
        else if (keys[1])
            xPos += 3;
        if (keys[2])
            yPos -= 3;
        else if (keys[3])
            yPos += 3;
    }
    public function render(framebuffer:Framebuffer):Void {
        if (!initialized)return;
        Triangle.triangles = new Array<Triangle>();
        var lv = vertices.length;
        for( i in 0...lv ) vertices.pop();
        var lc = colors.length;
        for( i in 0...lc ) colors.pop();
       
        graphicsTests();
        polykTest();
        poly2TriTest();
        
        
        var w = System.windowWidth() / 2;
        var h = System.windowHeight() / 2;
        var g = framebuffer.g2;
        var tri: Triangle;
        var triangles = Triangle.triangles;
        var s = 4;
        var offX = 5;
        var offY = 2;
        var toRGBs = toRGB;
        var adjScale: Float = 87.1;//200
        for( i in 0...triangles.length ){
            tri = triangles[ i ];
            vertices.push( s * tri.ax - offX );
            vertices.push( s * tri.ay - offY );
            vertices.push( -z );
            vertices.push( s * tri.bx - offX );
            vertices.push( s * tri.by - offY );
            vertices.push( -z );
            vertices.push( s * tri.cx - offX );
            vertices.push( s * tri.cy - offY );
            vertices.push( -z );
            var rgb = toRGBs( cast( rainbow[ tri.colorID ], Int ) );
            colors.push( rgb.r );
            colors.push( rgb.g );
            colors.push( rgb.b );
            colors.push( rgb.r );
            colors.push( rgb.g );
            colors.push( rgb.b );
            colors.push( rgb.r );
            colors.push( rgb.g );
            colors.push( rgb.b );
        }

        updateVectors();
        
        var g2 = pixelLayer.g2;
        //g2.imageScaleQuality = ImageScaleQuality.High;
        g2.begin(false);
        g2.clear(Color.fromValue(0x00000000));
        g2.drawImage(ball, xPos, yPos);
        g2.end();
        
        //vectorLayer = Image.createRenderTarget(1280, 720);
        var g4 = vectorLayer.g4;
        var g2 = vectorLayer.g2;
        //g2.imageScaleQuality = ImageScaleQuality.High;
        g4.begin();
        g4.clear(Color.fromValue(0xff000000));
        g4.setVertexBuffer(vertexBuffer);
        g4.setIndexBuffer(indexBuffer);
        g4.setPipeline(pipeline);
        g4.setMatrix(mvpID, mvp);
        g4.drawIndexedVertices();
        g4.end();
        
        var g2 = framebuffer.g2;
        g2.begin();
        g2.clear(Color.fromValue(0xff000000));
        //g2.imageScaleQuality = ImageScaleQuality.High;
        g2.drawImage( vectorLayer, 0, 0 );
        g2.drawImage( pixelLayer, 0, 0 );
        g2.end();
    }
    
    var quadtest_d = "M200,300 Q400,50 600,300 T1000,300";
    var cubictest_d = "M100,200 C100,100 250,100 250,200S400,300 400,200";
    var bird_d = "M210.333,65.331C104.367,66.105-12.349,150.637,1.056,276.449c4.303,40.393,18.533,63.704,52.171,79.03c36.307,16.544,57.022,54.556,50.406,112.954c-9.935,4.88-17.405,11.031-19.132,20.015c7.531-0.17,14.943-0.312,22.59,4.341c20.333,12.375,31.296,27.363,42.979,51.72c1.714,3.572,8.192,2.849,8.312-3.078c0.17-8.467-1.856-17.454-5.226-26.933c-2.955-8.313,3.059-7.985,6.917-6.106c6.399,3.115,16.334,9.43,30.39,13.098c5.392,1.407,5.995-3.877,5.224-6.991c-1.864-7.522-11.009-10.862-24.519-19.229c-4.82-2.984-0.927-9.736,5.168-8.351l20.234,2.415c3.359,0.763,4.555-6.114,0.882-7.875c-14.198-6.804-28.897-10.098-53.864-7.799c-11.617-29.265-29.811-61.617-15.674-81.681c12.639-17.938,31.216-20.74,39.147,43.489c-5.002,3.107-11.215,5.031-11.332,13.024c7.201-2.845,11.207-1.399,14.791,0c17.912,6.998,35.462,21.826,52.982,37.309c3.739,3.303,8.413-1.718,6.991-6.034c-2.138-6.494-8.053-10.659-14.791-20.016c-3.239-4.495,5.03-7.045,10.886-6.876c13.849,0.396,22.886,8.268,35.177,11.218c4.483,1.076,9.741-1.964,6.917-6.917c-3.472-6.085-13.015-9.124-19.18-13.413c-4.357-3.029-3.025-7.132,2.697-6.602c3.905,0.361,8.478,2.271,13.908,1.767c9.946-0.925,7.717-7.169-0.883-9.566c-19.036-5.304-39.891-6.311-61.665-5.225c-43.837-8.358-31.554-84.887,0-90.363c29.571-5.132,62.966-13.339,99.928-32.156c32.668-5.429,64.835-12.446,92.939-33.85c48.106-14.469,111.903,16.113,204.241,149.695c3.926,5.681,15.819,9.94,9.524-6.351c-15.893-41.125-68.176-93.328-92.13-132.085c-24.581-39.774-14.34-61.243-39.957-91.247c-21.326-24.978-47.502-25.803-77.339-17.365c-23.461,6.634-39.234-7.117-52.98-31.273C318.42,87.525,265.838,64.927,210.333,65.331zM445.731,203.01c6.12,0,11.112,4.919,11.112,11.038c0,6.119-4.994,11.111-11.112,11.111s-11.038-4.994-11.038-11.111C434.693,207.929,439.613,203.01,445.731,203.01z";
        
}