function love.conf(t)
    t.identity = "spaghetti"
    t.window.title = "스파게티"
    t.window.width = 450
    t.window.height = 800
    t.window.resizable = true
    t.window.minwidth = 360
    t.window.minheight = 640
    t.window.highdpi = true
    t.window.vsync = 1
    t.modules.joystick = false
    t.modules.video = false
end
