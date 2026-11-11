package com.wincoretech.challenger_timer

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import java.util.Random

/**
 * Feature 96: background noise generated in code (no audio files).
 * "brown" is integrated noise, "rain" is high-passed noise, "white" is flat.
 */
object Noise {
    @Volatile
    private var running = false
    private var thread: Thread? = null

    fun start(kind: String) {
        stop()
        running = true
        thread = Thread {
            val rate = 22050
            val size = AudioTrack.getMinBufferSize(rate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT).coerceAtLeast(4096)
            val track = try {
                AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(rate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build()
                    )
                    .setBufferSizeInBytes(size)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()
            } catch (e: Exception) {
                running = false
                return@Thread
            }
            val rnd = Random()
            val data = ShortArray(2048)
            var brown = 0.0
            var low = 0.0
            track.play()
            while (running) {
                for (i in data.indices) {
                    val white = rnd.nextDouble() * 2 - 1
                    val v = when (kind) {
                        "brown" -> {
                            brown = (brown + 0.02 * white) / 1.02
                            brown * 3.5
                        }
                        "rain" -> {
                            low = 0.6 * low + 0.4 * white
                            (white - low) * 0.5
                        }
                        else -> white * 0.25
                    }
                    data[i] = (v.coerceIn(-1.0, 1.0) * Short.MAX_VALUE * 0.5).toInt().toShort()
                }
                track.write(data, 0, data.size)
            }
            try {
                track.stop()
            } catch (e: Exception) {
                // Already stopped.
            }
            track.release()
        }.also { it.start() }
    }

    fun stop() {
        running = false
        try {
            thread?.join(500)
        } catch (e: InterruptedException) {
            // Give up waiting; the thread ends on its next loop.
        }
        thread = null
    }
}
