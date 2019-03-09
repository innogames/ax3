package ax3;

class FileLoader {
    var files:Map<String,{content:String, lines:Null<Array<Int>>}>;

    public function new() {
        files = new Map();
    }

    public function getContent(path:String):String {
        var file = files[path];
        if (file == null)
            file = files[path] = {content: sys.io.File.getContent(path), lines: null};
        return file.content;
    }

    public function formatPosition(path:String, pos:Int):String {
        var file = files[path];
        if (file == null)
            return path;

        if (file.lines == null)
            file.lines = initLines(file.content);

        var p = findLine(file.lines, pos);
        return '$path:${p.line + 1}: character ${p.pos + 1}';
    }

    function initLines(content:String):Array<Int> {
        var lines = [];
        // составляем массив позиций начала строк
        var s = 0, p = 0;
        while (p < content.length) {
            inline function nextChar() return StringTools.fastCodeAt(content, p++);
            inline function line() { lines.push(s); s = p; };
            switch (nextChar()) {
                case "\n".code:
                    line();
                case "\r".code:
                    p++;
                    line();
            }
        }
        return lines;
    }

    function findLine(lines:Array<Int>, pos:Int):{line:Int, pos:Int} {
        function loop(min, max) {
            var mid = (min + max) >> 1;
            var start = lines[mid];
            return
                if (mid == min)
                    {line: mid, pos: pos - start};
                else if (start > pos)
                    loop(min, mid);
                else
                    loop(mid, max);
        }
        return loop(0, lines.length);
    }
}
