package com.smapy.smapy

import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.InputStream
import java.io.InputStreamReader
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    private val runtimeChannel = "com.smapy/runtime"
    private val processChannel = "com.smapy/process"
    private val eventsChannel = "com.smapy/process-events"

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newCachedThreadPool()
    private val nextId = AtomicInteger(1)
    private val processes = mutableMapOf<Int, Process>()
    private var eventSink: EventChannel.EventSink? = null

    private fun runtimeBase() = File(filesDir, "smapy-runtime").canonicalFile

    private fun runtimeDirectories(): Map<String, File> {
        val base = runtimeBase()
        return mapOf(
            "base" to base,
            "rootfs" to File(base, "rootfs"),
            "bin" to File(base, "bin"),
            "downloads" to File(base, "downloads"),
            "tmp" to File(base, "tmp"),
            "home" to File(base, "home")
        )
    }

    private fun prepareRuntimeStorage(): Map<String, Any> {
        val directories = runtimeDirectories()

        directories.values.forEach { directory ->
            if (!directory.exists() && !directory.mkdirs()) {
                throw IllegalStateException(
                    "Could not create directory: ${directory.name}"
                )
            }
        }

        return mapOf(
            "prepared" to true,
            "storage" to "app-private",
            "directories" to directories.mapValues { it.value.absolutePath }
        )
    }

    private fun emit(event: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(event) }
    }

    private fun readOutput(id: Int, type: String, stream: InputStream) {
        try {
            BufferedReader(InputStreamReader(stream)).use { reader ->
                while (true) {
                    val line = reader.readLine() ?: break
                    emit(
                        mapOf(
                            "type" to type,
                            "processId" to id,
                            "text" to line
                        )
                    )
                }
            }
        } catch (error: Exception) {
            emit(
                mapOf(
                    "type" to "error",
                    "processId" to id,
                    "text" to (error.message ?: "Output reader failed")
                )
            )
        }
    }

    private fun startProcess(
        call: io.flutter.plugin.common.MethodCall
    ): Int {
        val executablePath = call.argument<String>("executablePath")
            ?: throw IllegalArgumentException("Missing executablePath")
        val workingDirectory = call.argument<String>("workingDirectory")
            ?: throw IllegalArgumentException("Missing workingDirectory")
        val arguments = call.argument<List<String>>("arguments") ?: emptyList()

        val base = runtimeBase()
        val executable = File(executablePath).canonicalFile
        val cwd = File(workingDirectory).canonicalFile
        val basePath = base.path + File.separator

        require(executable.path.startsWith(basePath)) {
            "Executable must be inside SMAPY runtime storage."
        }
        require(cwd.path == base.path || cwd.path.startsWith(basePath)) {
            "Working directory must be inside SMAPY runtime storage."
        }
        require(executable.isFile && executable.canExecute()) {
            "Executable is missing or not executable."
        }
        require(cwd.isDirectory) { "Working directory does not exist." }
        require(arguments.size <= 256 && arguments.none {
            it.contains('\u0000')
        }) {
            "Invalid process arguments."
        }

        val process = ProcessBuilder(
            listOf(executable.absolutePath) + arguments
        ).directory(cwd).redirectErrorStream(false).start()

        val id = nextId.getAndIncrement()
        synchronized(processes) { processes[id] = process }

        executor.execute { readOutput(id, "stdout", process.inputStream) }
        executor.execute { readOutput(id, "stderr", process.errorStream) }

        executor.execute {
            try {
                val exitCode = process.waitFor()
                emit(
                    mapOf(
                        "type" to "exit",
                        "processId" to id,
                        "text" to "Process finished",
                        "exitCode" to exitCode
                    )
                )
            } catch (error: InterruptedException) {
                Thread.currentThread().interrupt()
            } finally {
                synchronized(processes) { processes.remove(id) }
            }
        }

        emit(
            mapOf(
                "type" to "started",
                "processId" to id,
                "text" to "Process started"
            )
        )

        return id
    }

    private fun writeInput(id: Int, text: String) {
        require(!text.contains('\u0000')) { "Invalid process input." }

        val process = synchronized(processes) { processes[id] }
            ?: throw IllegalArgumentException("Process is not running.")

        process.outputStream.apply {
            write(text.toByteArray(Charsets.UTF_8))
            flush()
        }
    }

    private fun closeInput(id: Int) {
        val process = synchronized(processes) { processes[id] }
            ?: return
        process.outputStream.close()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            runtimeChannel
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getDeviceInfo" -> result.success(
                        mapOf(
                            "platform" to "Android",
                            "androidVersion" to Build.VERSION.RELEASE,
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
                            "primaryAbi" to Build.SUPPORTED_ABIS.firstOrNull().orEmpty()
                        )
                    )
                    "prepareRuntimeStorage" ->
                        result.success(prepareRuntimeStorage())
                    "getRuntimePaths" ->
                        result.success(
                            runtimeDirectories().mapValues { it.value.absolutePath }
                        )
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("RUNTIME_ERROR", error.message, null)
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventsChannel
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(
                arguments: Any?,
                events: EventChannel.EventSink
            ) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            processChannel
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startProcess" -> result.success(startProcess(call))
                    "writeInput" -> {
                        val id = call.argument<Int>("processId")
                            ?: throw IllegalArgumentException("Missing processId")
                        val text = call.argument<String>("text")
                            ?: throw IllegalArgumentException("Missing text")
                        writeInput(id, text)
                        result.success(null)
                    }
                    "closeInput" -> {
                        val id = call.argument<Int>("processId")
                            ?: throw IllegalArgumentException("Missing processId")
                        closeInput(id)
                        result.success(null)
                    }
                    "stopProcess" -> {
                        val id = call.argument<Int>("processId")
                            ?: throw IllegalArgumentException("Missing processId")
                        synchronized(processes) { processes[id] }?.destroy()
                        result.success(null)
                    }
                    "getProcessStatus" -> {
                        val ids = synchronized(processes) { processes.keys.toList() }
                        result.success(
                            mapOf("activeProcessIds" to ids, "activeCount" to ids.size)
                        )
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("PROCESS_ERROR", error.message, null)
            }
        }
    }

    override fun onDestroy() {
        synchronized(processes) {
            processes.values.forEach { it.destroy() }
            processes.clear()
        }
        executor.shutdownNow()
        super.onDestroy()
    }
}
