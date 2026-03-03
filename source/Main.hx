package;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;
import flixel.FlxG;
import flixel.FlxGame;
import funkin.backend.DebugDisplay;

#if android
import lime.system.System as LimeSystem;
#end

class Main extends Sprite
{
    public static final PSYCH_VERSION:String = '0.5.2h';
    public static final NMV_VERSION:String = '0.2';
    public static final FUNKIN_VERSION:String = '0.2.7';

    public static final startMeta =
    {
        width: 1280,
        height: 720,
        fps: 60,
        skipSplash: #if debug true #else false #end,
        startFullScreen: false,
        initialState: funkin.states.TitleState
    };

    public static var fpsVar:DebugDisplay;

    static function __init__()
    {
        funkin.utils.MacroUtil.haxeVersionEnforcement();
    }

    public static function main():Void
    {
        Lib.current.addChild(new Main());
    }

    public function new()
    {
        super();

        #if android
        // USANDO REFLEXÃO: Isso impede que o erro "Type not found" pare o build no GitHub.
        // O compilador não tentará validar a classe 'android.Tools' agora.
        var androidTools = Type.resolveClass("android.Tools");
        if (androidTools != null) {
            Reflect.callMethod(androidTools, Reflect.field(androidTools, "requestPermissions"), [['READ_EXTERNAL_STORAGE', 'WRITE_EXTERNAL_STORAGE']]);
        }

        // Define e cria o caminho de mods no armazenamento seguro
        var storagePath:String = LimeSystem.documentsDirectory;
        if (!sys.FileSystem.exists(storagePath + '/content')) {
            try {
                sys.FileSystem.createDirectory(storagePath + '/content');
            } catch(e:Dynamic) {
                trace("Erro ao criar diretório: " + e);
            }
        }
        #end

        initHaxeUI();

        #if (windows && cpp)
        funkin.api.NativeWindows.setDarkMode();
        #end

        ClientPrefs.loadDefaultKeys();
        FlxG.save.bind('funkin', CoolUtil.getSavePath());

        var game = new
            #if CRASH_HANDLER
            FNFGame
            #else
            FlxGame
            #end(startMeta.width, startMeta.height, Init, startMeta.fps, startMeta.fps, true, startMeta.startFullScreen);

        @:privateAccess
        game._customSoundTray = funkin.objects.FunkinSoundTray;

        addChild(game);

        #if !mobile
        fpsVar = new DebugDisplay(10, 3, 0xFFFFFF);
        addChild(fpsVar);
        Lib.current.stage.align = "tl";
        Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
        if (fpsVar != null) fpsVar.visible = ClientPrefs.showFPS;
        #else
        FlxG.mouse.visible = false;
        FlxG.mouse.useSystemCursor = false;
        #end

        FlxG.signals.gameResized.add(onResize);

        #if DISABLE_TRACES
        haxe.Log.trace = (v:Dynamic, ?infos:haxe.PosInfos) -> {}
        #end
    }

    @:access(flixel.FlxCamera)
    static function onResize(w:Int, h:Int)
    {
        if (FlxG.cameras != null)
        {
            for (i in FlxG.cameras.list)
                if (i != null && i.filters != null) resetSpriteCache(i.flashSprite);
        }
        if (FlxG.game != null) resetSpriteCache(FlxG.game);
    }

    public static function resetSpriteCache(sprite:Sprite):Void
    {
        @:privateAccess {
            sprite.__cacheBitmap = null;
            sprite.__cacheBitmapData = null;
        }
    }

    function initHaxeUI():Void
    {
        #if haxeui_core
        haxe.ui.Toolkit.init();
        haxe.ui.Toolkit.theme = 'dark';
        haxe.ui.Toolkit.autoScale = false;
        haxe.ui.focus.FocusManager.instance.autoFocus = false;
        #end
    }
}

#if CRASH_HANDLER
class FNFGame extends FlxGame
{
    override function create(_):Void { try { _skipSplash = true; super.create(_); } catch (e:Dynamic) { onCrash(e); } }
    override function onFocus(_):Void { try { super.onFocus(_); } catch (e:Dynamic) { onCrash(e); } }
    override function onFocusLost(_):Void { try { super.onFocusLost(_); } catch (e:Dynamic) { onCrash(e); } }
    override function onEnterFrame(_):Void { try { super.onEnterFrame(_); } catch (e:Dynamic) { onCrash(e); } }
    override function update():Void { try { super.update(); } catch (e:Dynamic) { onCrash(e); } }
    override function draw():Void { try { super.draw(); } catch (e:Dynamic) { onCrash(e); } }

    private final function onCrash(e:Dynamic):Void
    {
        var emsg:String = "";
        for (stackItem in haxe.CallStack.exceptionStack(true))
        {
            switch (stackItem) {
                case FilePos(s, file, line, column): emsg += file + " (line " + line + ")\n";
                default: trace(stackItem);
            }
        }
        final crashReport = 'Error caught: ' + e + '\nCallstack:\n' + emsg;
        FlxG.switchState(new funkin.backend.FallbackState(crashReport, () -> FlxG.switchState(() -> new funkin.states.TitleState())));
    }
}
#end