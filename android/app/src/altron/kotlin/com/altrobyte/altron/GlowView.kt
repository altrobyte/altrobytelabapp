package com.altrobyte.altron

import android.content.Context
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Shader
import android.view.View

/** The strip's light: a radium-green and cyan line that flows along the top of the screen, with a soft glow under it.
 *  Brighter and thicker while Altron speaks; red when something went wrong. */
class GlowView(context: Context) : View(context) {
    var speaking = false
        set(v) { field = v; invalidate() }
    var problem = false
        set(v) { field = v; invalidate() }

    private val line = Paint(Paint.ANTI_ALIAS_FLAG)
    private val halo = Paint(Paint.ANTI_ALIAS_FLAG)
    private val shift = Matrix()
    private var shader: LinearGradient? = null
    private var colors = intArrayOf()

    init { setLayerType(LAYER_TYPE_SOFTWARE, null) }        // the blur of the glow needs it

    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        val d = resources.displayMetrics.density
        val want = if (problem) intArrayOf(Color.rgb(255, 82, 82), Color.rgb(255, 138, 128), Color.rgb(255, 82, 82))
                   else intArrayOf(Color.rgb(0, 229, 255), Color.rgb(118, 255, 3), Color.rgb(0, 229, 255))
        if (shader == null || !want.contentEquals(colors)) {
            colors = want
            shader = LinearGradient(0f, 0f, w, 0f, colors, null, Shader.TileMode.MIRROR)
        }
        val s = shader!!
        shift.setTranslate((System.currentTimeMillis() % 1600) / 1600f * w * 2, 0f)
        s.setLocalMatrix(shift)
        val strong = speaking || problem
        val h = (if (strong) 5f else 3f) * d
        halo.shader = s
        halo.alpha = if (strong) 230 else 140
        halo.maskFilter = BlurMaskFilter((if (strong) 9f else 5f) * d, BlurMaskFilter.Blur.NORMAL)
        canvas.drawRect(0f, 0f, w, h + 4 * d, halo)
        line.shader = s
        canvas.drawRect(0f, 0f, w, h, line)
        postInvalidateOnAnimation()
    }
}
