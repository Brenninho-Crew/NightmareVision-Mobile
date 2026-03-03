package;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;
import flixel.FlxG;
import flixel.FlxGame;
import funkin.backend.DebugDisplay;

// Importações específicas para Android protegidas
#if android
import android.Tools as AndroidTools;
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
        // Solicita permissões usando o alias seguro
        AndroidTools.requestPermissions(['READ_EXTERNAL_STORAGE', 'WRITE_EXTERNAL_STORAGE']);

        // Define e cria o caminho de mods no armazenamento seguro do app
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

        // Carrega as preferências antes de iniciar o jogo
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
        if (fpsVar != null)
        {
            fpsVar.visible = ClientPrefs.showFPS;
        }
        #else
        // Melhora a performance mobile desativando o cursor
        FlxG.mouse.visible = false;
        FlxG.mouse.useSystemCursor = false;
        #end

        #if html5
        FlxG.autoPause = false;
        FlxG.mouse.visible = false;
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
            {
                if (i != null && i.filters != null) resetSpriteCache(i.flashSprite);
            }
        }

        if (FlxG.game != null)
        {
            resetSpriteCache(FlxG.game);
        }
    }

    public static function resetSpriteCache(sprite:Sprite):Void
    {
        @:privateAccess
        {
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
    override function create(_):Void
    {
        try {
            _skipSplash = true;
            super.create(_);
        } catch (e:Dynamic) { onCrash(e); }
    }

    override function onFocus(_):Void { try { super.onFocus(_); } catch (e:Dynamic) { onCrash(e); } }
    override function onFocusLost(_):Void { try { super.onFocusLost(_); } catch (e:Dynamic) { onCrash(e); } }
    override function onEnterFrame(_):Void { try { super.onEnterFrame(_); } catch (e:Dynamic) { onCrash(e); } }
    override function update():Void { try { super.update(); } catch (e:Dynamic) { onCrash(e); } }
    override function draw():Void { try { super.draw(); } catch (e:Dynamic) { onCrash(e); } }

    private final function onCrash(e:haxe.Exception):Void
    {
        var emsg:String = "";
        for (stackItem in haxe.CallStack.exceptionStack(true))
        {
            switch (stackItem)
            {
                case FilePos(s, file, line, column):
                    emsg += file + " (line " + line + ")\n";
                default:
                    trace(stackItem);
            }
        }
        final crashReport = 'Error caught: ' + e.message + '\nCallstack:\n' + emsg;
        FlxG.switchState(new funkin.backend.FallbackState(crashReport, () -> FlxG.switchState(() -> new TitleState())));
    }
}
#end