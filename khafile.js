var project = new Project('GraphicsKha');

project.addAssets('Assets/**');
project.addSources('Sources');
project.addShaders('Sources/Shaders/**');
project.addLibrary('poly2trihx');
project.addLibrary('justTriangles');
resolve(project);
