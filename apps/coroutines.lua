hg = require("harfang")
require("utils")

function PhotoChangeCoroutine()
    -- load next photo
    current_photo = current_photo + 1
    if current_photo > #photo_table then
        current_photo = 1
    end
    next_tex = LoadPhotoFromTable(photo_table, current_photo)
    coroutine.yield()
    
    -- ramp up the noise intensity
    start_clock = hg.GetClock()
    while true do
        clock = hg.GetClock() - start_clock
        clock_s = hg.time_to_sec_f(clock)
        noise_intensity = clock_s + 2.0 * clamp(map(clock_s, 0.8, 1.0, 0.0, 1.0), 0.0, 1.0)
        if clock_s >= 1.0 then
            break
        end
        coroutine.yield()
    end

    -- next photo
    noise_intensity = 1.0
    tex_photo0 = next_tex
    next_tex = nil
    coroutine.yield()
    
    -- ramp down the noise intensity
    start_clock = hg.GetClock()
    while true do
        clock = hg.GetClock() - start_clock
        clock_s = hg.time_to_sec_f(clock)
        noise_intensity = clock_s + 2.0 * clamp(map(clock_s, 0.8, 1.0, 0.0, 1.0), 0.0, 1.0)
        noise_intensity = 1.0 - noise_intensity
        if clock_s >= 1.0 then
            break
        end
        coroutine.yield()
    end

    noise_intensity = 0.0
    coroutine.yield()
end