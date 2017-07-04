package;
import kha.Scheduler;
import kha.System;
import JustTrianglesKha4;
class Main {
    public static function main(){
        System.init({title: "JustTrianglesKha4", width: 800, height: 600},initialized);
    }
    static function initialized():Void {
        var game = new JustTrianglesKha4();
        System.notifyOnRender(game.render);
        Scheduler.addTimeTask(game.update, 0, 1 / 60);
    }
}