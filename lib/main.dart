package com.example.llama

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.ResolveInfo
import android.graphics.Color
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.StatFs
import android.provider.OpenableColumns
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.widget.ArrayAdapter
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.arm.aichat.AiChat
import com.arm.aichat.InferenceEngine
import com.google.android.material.button.MaterialButton
import com.google.android.material.card.MaterialCardView
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.IOException
import java.net.URLEncoder
import java.text.DecimalFormat
import java.util.Locale

/**
 * NOUR - local AI assistant for the official llama.cpp Android binding.
 *
 * Place this file at:
 * examples/llama.android/app/src/main/java/com/example/llama/MainActivity.kt
 * in the official ggml-org/llama.cpp repository.
 */
class MainActivity : AppCompatActivity() {

    private val bg = Color.rgb(10, 14, 25)
    private val panel = Color.rgb(19, 27, 44)
    private val panelRaised = Color.rgb(27, 38, 59)
    private val textPrimary = Color.rgb(239, 243, 255)
    private val textSecondary = Color.rgb(158, 174, 202)
    private val accent = Color.rgb(128, 153, 255)
    private val userBubble = Color.rgb(42, 59, 95)
    private val aiBubble = Color.rgb(20, 30, 48)

    private lateinit var root: LinearLayout
    private lateinit var statusText: TextView
    private lateinit var modelText: TextView
    private lateinit var messagesScroll: ScrollView
    private lateinit var messagesContainer: LinearLayout
    private lateinit var inputText: EditText
    private lateinit var sendButton: MaterialButton
    private lateinit var addModelButton: MaterialButton
    private lateinit var modelListButton: MaterialButton
    private lateinit var toolsButton: MaterialButton

    private var engine: InferenceEngine? = null
    private var activeModel: File? = null
    private var generationJob: Job? = null
    private var isLoading = false
    private var isGenerating = false
    private var torchEnabled = false
    private var requestedTorchState: Boolean? = null
    private var pendingExportText = ""
    private var pendingExportName = "NOUR-response.txt"
    private val modelPrefs by lazy { getSharedPreferences("nour_models", MODE_PRIVATE) }
    private val modelsDir by lazy { File(filesDir, "models").apply { mkdirs() } }

    private data class ChatEntry(val role: String, val text: String)
    private val visibleConversation = mutableListOf<ChatEntry>()

    private val pickModel = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) importModel(uri)
    }

    private val exportFile = registerForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) { uri ->
        if (uri != null) {
            lifecycleScope.launch(Dispatchers.IO) {
                try {
                    contentResolver.openOutputStream(uri)?.bufferedWriter(Charsets.UTF_8)?.use { it.write(pendingExportText) }
                    withContext(Dispatchers.Main) { toast("تم حفظ الملف.") }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) { toast("تعذر حفظ الملف: ${e.message ?: "خطأ غير معروف"}") }
                }
            }
        }
    }

    private val askForCamera = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            val wanted = requestedTorchState
            requestedTorchState = null
            if (wanted == null) changeTorch() else setTorch(wanted)
        } else {
            requestedTorchState = null
            toast("لم تمنح إذن الكاميرا، لذلك لم أستطع تشغيل الفلاش.")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        supportActionBar?.hide()
        window.statusBarColor = bg
        window.navigationBarColor = bg
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        buildInterface()
        addBubble("assistant", "أهلاً بيك، أني نَوْر. أضف ملف GGUF من زر «إضافة نموذج»، حمّله، وبعدها تگدر تحچي وياه. أگدر أيضاً أفتح إعدادات الهاتف والتطبيقات من أدوات الهاتف، ضمن الصلاحيات اللي يسمح بيها Android.")

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val localEngine = AiChat.getInferenceEngine(applicationContext)
                withContext(Dispatchers.Main) {
                    engine = localEngine
                    statusText.text = "المحرك جاهز، بانتظار تحميل نموذج"
                }
                awaitEngineReady(localEngine)
                val lastPath = modelPrefs.getString("active_model_path", null)
                val lastModel = lastPath?.let { File(it) }?.takeIf { it.isFile && it.extension.equals("gguf", true) }
                if (lastModel != null) activateModel(lastModel, clearChat = false)
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    statusText.text = "تعذر تهيئة المحرك"
                    toast("تعذر تشغيل محرك الذكاء الاصطناعي: ${e.message ?: "راجع بناء التطبيق"}")
                }
            }
        }
    }

    private fun buildInterface() {
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(bg)
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            setPadding(dp(14), dp(12), dp(14), dp(8))
        }
        setContentView(root)

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_LTR
        }
        val brandColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }
        brandColumn.addView(label("نَوْر", 27f, textPrimary, true))
        brandColumn.addView(label("NOUR  ·  مساعد ذكاء اصطناعي محلي", 12f, textSecondary))
        header.addView(brandColumn, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val clearButton = actionButton("محادثة جديدة", false)
        clearButton.setOnClickListener { resetConversation() }
        header.addView(clearButton, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(42)))
        root.addView(header)

        val stateCard = MaterialCardView(this).apply {
            radius = dp(18).toFloat()
            cardElevation = 0f
            setCardBackgroundColor(panel)
            strokeColor = Color.rgb(42, 54, 78)
            strokeWidth = dp(1)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(14)
                bottomMargin = dp(10)
            }
        }
        val stateColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(12), dp(14), dp(12))
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }
        modelText = label("ماكو نموذج محمّل حالياً", 15f, textPrimary, true)
        statusText = label("جاري تهيئة المحرك المحلي…", 12f, textSecondary)
        stateColumn.addView(modelText)
        stateColumn.addView(statusText, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(4) })
        stateCard.addView(stateColumn)
        root.addView(stateCard)

        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }
        addModelButton = actionButton("＋ إضافة نموذج", true)
        modelListButton = actionButton("النماذج", false)
        toolsButton = actionButton("أدوات الهاتف", false)
        addModelButton.setOnClickListener { pickModel.launch(arrayOf("*/*")) }
        modelListButton.setOnClickListener { showModelLibrary() }
        toolsButton.setOnClickListener { showPhoneTools() }
        listOf(addModelButton, modelListButton, toolsButton).forEach { button ->
            controls.addView(button, LinearLayout.LayoutParams(0, dp(46), 1f).apply {
                marginStart = dp(3)
                marginEnd = dp(3)
            })
        }
        root.addView(controls)

        messagesScroll = ScrollView(this).apply {
            isFillViewport = false
            clipToPadding = false
            setPadding(0, dp(8), 0, dp(8))
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
        }
        messagesContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }
        messagesScroll.addView(messagesContainer)
        root.addView(messagesScroll)

        val inputCard = MaterialCardView(this).apply {
            radius = dp(20).toFloat()
            cardElevation = 0f
            setCardBackgroundColor(panelRaised)
            strokeColor = Color.rgb(48, 62, 88)
            strokeWidth = dp(1)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(5)
            }
        }
        val composer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            setPadding(dp(7), dp(5), dp(7), dp(5))
        }
        inputText = EditText(this).apply {
            hint = "اكتب رسالتك أو أمراً للهاتف…"
            setHintTextColor(textSecondary)
            setTextColor(textPrimary)
            textSize = 15f
            background = null
            minHeight = dp(48)
            maxLines = 5
            setPadding(dp(9), dp(5), dp(9), dp(5))
            imeOptions = EditorInfo.IME_ACTION_SEND
            inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE or android.text.InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }
        sendButton = actionButton("إرسال", true).apply {
            minWidth = dp(68)
            setOnClickListener { sendCurrentMessage() }
        }
        inputText.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_SEND) {
                sendCurrentMessage()
                true
            } else false
        }
        composer.addView(inputText, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        composer.addView(sendButton, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(46)))
        inputCard.addView(composer)
        root.addView(inputCard)
        root.addView(label("المعالجة داخل الجهاز • لا حاجة إلى API", 10f, textSecondary).apply {
            gravity = Gravity.CENTER
            setPadding(0, dp(7), 0, 0)
        })
    }

    private fun label(value: String, size: Float, color: Int, bold: Boolean = false): TextView = TextView(this).apply {
        text = value
        textSize = size
        setTextColor(color)
        if (bold) setTypeface(typeface, android.graphics.Typeface.BOLD)
        gravity = Gravity.CENTER_VERTICAL
        textDirection = View.TEXT_DIRECTION_FIRST_STRONG
    }

    private fun actionButton(value: String, primary: Boolean): MaterialButton = MaterialButton(this).apply {
        text = value
        textSize = 12.5f
        isAllCaps = false
        cornerRadius = dp(13)
        insetTop = 0
        insetBottom = 0
        setTextColor(if (primary) Color.rgb(12, 20, 39) else textPrimary)
        backgroundTintList = android.content.res.ColorStateList.valueOf(if (primary) accent else panelRaised)
        strokeWidth = if (primary) 0 else dp(1)
        strokeColor = android.content.res.ColorStateList.valueOf(Color.rgb(57, 70, 99))
        elevation = 0f
    }

    private fun addBubble(role: String, text: String): TextView {
        val isUser = role == "user"
        val card = MaterialCardView(this).apply {
            radius = dp(18).toFloat()
            cardElevation = 0f
            setCardBackgroundColor(if (isUser) userBubble else aiBubble)
            strokeColor = if (isUser) Color.rgb(66, 91, 143) else Color.rgb(40, 53, 76)
            strokeWidth = dp(1)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(5)
                bottomMargin = dp(5)
            }
        }
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(11), dp(14), dp(11))
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }
        column.addView(label(if (isUser) "أنت" else "نَوْر", 11f, if (isUser) Color.rgb(190, 207, 255) else accent, true))
        val body = TextView(this).apply {
            this.text = text
            textSize = 15.5f
            setTextColor(textPrimary)
            textDirection = View.TEXT_DIRECTION_FIRST_STRONG
            setTextIsSelectable(true)
            setLineSpacing(dp(2).toFloat(), 1.05f)
            setPadding(0, dp(5), 0, 0)
        }
        column.addView(body)
        if (!isUser) {
            val actions = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.END
                layoutDirection = View.LAYOUT_DIRECTION_LTR
                setPadding(0, dp(4), 0, 0)
            }
            val copy = tinyButton("نسخ") { copyText(body.text.toString()) }
            val share = tinyButton("مشاركة") { shareText(body.text.toString()) }
            val save = tinyButton("حفظ") { saveText(body.text.toString()) }
            actions.addView(copy)
            actions.addView(share)
            actions.addView(save)
            column.addView(actions)
        }
        card.addView(column)
        messagesContainer.addView(card)
        if (text.isNotEmpty()) visibleConversation.add(ChatEntry(role, text))
        scrollToLatest()
        return body
    }

    private fun tinyButton(text: String, click: () -> Unit) = TextView(this).apply {
        this.text = text
        textSize = 11f
        setTextColor(textSecondary)
        gravity = Gravity.CENTER
        setPadding(dp(8), dp(6), dp(8), dp(6))
        setOnClickListener { click() }
    }

    private fun scrollToLatest() {
        messagesScroll.post { messagesScroll.fullScroll(View.FOCUS_DOWN) }
    }

    private fun sendCurrentMessage() {
        val prompt = inputText.text?.toString()?.trim().orEmpty()
        if (prompt.isEmpty() || isGenerating || isLoading) return
        inputText.text?.clear()
        addBubble("user", prompt)
        if (runPhoneCommand(prompt)) return

        val localEngine = engine
        if (activeModel == null || localEngine == null) {
            addBubble("assistant", "أضف نموذج GGUF وحمّله أولاً من أزرار النماذج بالأعلى.")
            return
        }

        isGenerating = true
        setComposerEnabled(false)
        statusText.text = "نَوْر يكتب…"
        val answer = StringBuilder()
        val answerView = addBubble("assistant", "")
        val answerEntryIndex = visibleConversation.size
        generationJob = lifecycleScope.launch(Dispatchers.IO) {
            try {
                localEngine.sendUserPrompt(prompt).collect { token ->
                    withContext(Dispatchers.Main) {
                        answer.append(token)
                        answerView.text = answer.toString()
                        if (answerEntryIndex == visibleConversation.size) {
                            visibleConversation.add(ChatEntry("assistant", answer.toString()))
                        } else if (answerEntryIndex < visibleConversation.size) {
                            visibleConversation[answerEntryIndex] = ChatEntry("assistant", answer.toString())
                        }
                        scrollToLatest()
                    }
                }
                withContext(Dispatchers.Main) {
                    if (answer.isEmpty()) answerView.text = "ما وصلني رد نصّي من النموذج."
                    statusText.text = "جاهز • ${activeModel?.name ?: "بدون نموذج"}"
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    answerView.text = "صار خطأ أثناء التوليد: ${e.message ?: "خطأ غير معروف"}"
                    statusText.text = "توقّف التوليد بسبب خطأ"
                }
            } finally {
                withContext(Dispatchers.Main) {
                    isGenerating = false
                    setComposerEnabled(true)
                    generationJob = null
                }
            }
        }
    }

    private fun setComposerEnabled(enabled: Boolean) {
        inputText.isEnabled = enabled
        sendButton.isEnabled = enabled
        addModelButton.isEnabled = enabled
        modelListButton.isEnabled = enabled
        toolsButton.isEnabled = enabled
    }

    private suspend fun haltGeneration() {
        generationJob?.cancelAndJoin()
        generationJob = null
        isGenerating = false
        withContext(Dispatchers.Main) { setComposerEnabled(true) }
    }

    private fun importModel(uri: Uri) {
        if (isLoading) return
        lifecycleScope.launch {
            isLoading = true
            setComposerEnabled(false)
            statusText.text = "جارٍ فحص ملف النموذج…"
            try {
                val (file, alreadyExisted) = withContext(Dispatchers.IO) { copyModelIntoPrivateStorage(uri) }
                statusText.text = if (alreadyExisted) "النموذج موجود مسبقاً في المكتبة" else "تمت إضافة النموذج إلى المكتبة"
                AlertDialog.Builder(this@MainActivity)
                    .setTitle("تمت إضافة النموذج")
                    .setMessage("${file.name}\nالحجم: ${formatSize(file.length())}\n\nتريد تحميله هسه؟")
                    .setPositiveButton("تحميل الآن") { _, _ -> activateModel(file) }
                    .setNegativeButton("لاحقاً", null)
                    .show()
            } catch (e: Exception) {
                statusText.text = "فشلت إضافة النموذج"
                toast(e.message ?: "تعذر استيراد ملف النموذج")
            } finally {
                isLoading = false
                setComposerEnabled(true)
            }
        }
    }

    private fun copyModelIntoPrivateStorage(uri: Uri): Pair<File, Boolean> {
        val originalName = queryDisplayName(uri) ?: "model-${System.currentTimeMillis()}.gguf"
        if (!originalName.lowercase(Locale.ROOT).endsWith(".gguf")) {
            throw IOException("اختر ملفاً ينتهي امتداده بـ .gguf")
        }

        val expectedSize = queryFileSize(uri)
        if (expectedSize != null && expectedSize > 0L) {
            val available = StatFs(filesDir.absolutePath).availableBytes
            if (available < expectedSize + 64L * 1024L * 1024L) {
                throw IOException("المساحة الحرة داخل التطبيق غير كافية لنسخ النموذج. وفر ${formatSize(expectedSize + 64L * 1024L * 1024L)} تقريباً.")
            }
        }

        contentResolver.openInputStream(uri)?.use { input ->
            val magic = ByteArray(4)
            if (input.read(magic) != 4 || String(magic, Charsets.US_ASCII) != "GGUF") {
                throw IOException("الملف المحدد لا يبدو ملف GGUF صالحاً")
            }
        } ?: throw IOException("تعذر فتح الملف المحدد")

        val safeName = originalName.replace(Regex("[^\\p{L}\\p{N}._() -]"), "_").take(120).ifBlank { "model.gguf" }
        var destination = File(modelsDir, safeName)
        if (destination.exists()) {
            if (expectedSize != null && expectedSize > 0L && destination.length() == expectedSize) return destination to true
            val stem = safeName.removeSuffix(".gguf")
            destination = File(modelsDir, "$stem-${System.currentTimeMillis()}.gguf")
        }
        val partFile = File(modelsDir, destination.name + ".part")
        if (partFile.exists()) partFile.delete()
        var copied = 0L
        var lastUiUpdate = 0L
        try {
            contentResolver.openInputStream(uri)?.buffered()?.use { input ->
                partFile.outputStream().buffered().use { output ->
                    val buffer = ByteArray(1024 * 1024)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        output.write(buffer, 0, count)
                        copied += count
                        if (copied - lastUiUpdate >= 64L * 1024L * 1024L) {
                            lastUiUpdate = copied
                            runOnUiThread { statusText.text = "جارٍ نسخ النموذج: ${formatSize(copied)}" }
                        }
                    }
                }
            } ?: throw IOException("تعذر فتح الملف مرة ثانية")
            if (partFile.length() < 4L) throw IOException("ملف النموذج فارغ أو غير مكتمل")
            if (!partFile.renameTo(destination)) {
                partFile.copyTo(destination, overwrite = true)
                partFile.delete()
            }
        } catch (e: Exception) {
            partFile.delete()
            throw e
        }
        return destination to false
    }

    private fun queryDisplayName(uri: Uri): String? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME)) else null
        }
    } catch (_: Exception) { null }

    private fun queryFileSize(uri: Uri): Long? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else null
        }
    } catch (_: Exception) { null }

    private fun showModelLibrary() {
        val models = modelsDir.listFiles { file -> file.isFile && file.extension.equals("gguf", true) }
            ?.sortedBy { it.name.lowercase(Locale.ROOT) }.orEmpty()
        if (models.isEmpty()) {
            AlertDialog.Builder(this)
                .setTitle("مكتبة النماذج")
                .setMessage("ما أضفت أي نموذج بعد. اختَر ملف .gguf من زر «إضافة نموذج».")
                .setPositiveButton("إضافة نموذج") { _, _ -> pickModel.launch(arrayOf("*/*")) }
                .setNegativeButton("إغلاق", null)
                .show()
            return
        }
        val labels = models.map { file ->
            val activeMark = if (activeModel?.absolutePath == file.absolutePath) "  ✓ نشط" else ""
            "${file.name}\n${formatSize(file.length())}$activeMark"
        }.toTypedArray()
        AlertDialog.Builder(this)
            .setTitle("نماذجك المحفوظة (${models.size})")
            .setItems(labels) { _, index -> showModelActions(models[index]) }
            .setPositiveButton("إضافة نموذج") { _, _ -> pickModel.launch(arrayOf("*/*")) }
            .setNegativeButton("إغلاق", null)
            .show()
    }

    private fun showModelActions(file: File) {
        val active = activeModel?.absolutePath == file.absolutePath
        val options = if (active) arrayOf("النموذج نشط حالياً", "حذف النموذج من الجهاز") else arrayOf("تحميل هذا النموذج", "حذف النموذج من الجهاز")
        AlertDialog.Builder(this)
            .setTitle(file.name)
            .setMessage("الحجم: ${formatSize(file.length())}\n\nيتم تحميل نموذج واحد فقط في الذاكرة. باقي النماذج تبقى محفوظة وتكدر تبدّل بينها.")
            .setItems(options) { _, which ->
                if (which == 0 && !active) activateModel(file)
                else if (which == 1) confirmDeleteModel(file)
            }
            .setNegativeButton("رجوع", null)
            .show()
    }

    private fun confirmDeleteModel(file: File) {
        if (activeModel?.absolutePath == file.absolutePath) {
            toast("ما تگدر تحذف النموذج النشط. حمّل نموذجاً آخر أولاً.")
            return
        }
        AlertDialog.Builder(this)
            .setTitle("حذف النموذج؟")
            .setMessage("راح ينحذف الملف من مساحة التطبيق فقط:\n${file.name}")
            .setNegativeButton("إلغاء", null)
            .setPositiveButton("حذف") { _, _ ->
                val previousSize = file.length()
                val deleted = file.delete()
                toast(if (deleted) "تم حذف النموذج وتحرير ${formatSize(previousSize)}" else "تعذر حذف الملف")
                showModelLibrary()
            }
            .show()
    }

    private fun activateModel(file: File, clearChat: Boolean = true) {
        if (!file.isFile) {
            toast("ملف النموذج غير موجود")
            return
        }
        lifecycleScope.launch {
            isLoading = true
            try {
                haltGeneration()
                setComposerEnabled(false)
                statusText.text = "جارٍ تحميل ${file.name}…"
                val localEngine = engine ?: withContext(Dispatchers.IO) { AiChat.getInferenceEngine(applicationContext) }.also { engine = it }
                awaitEngineReady(localEngine)
                // The official binding is a singleton and permits one loaded model. Unload the old
                // native context/model before loading another file to avoid retaining both in RAM.
                if (activeModel != null) {
                    localEngine.cleanUp()
                    activeModel = null
                    modelPrefs.edit().remove("active_model_path").apply()
                }
                withContext(Dispatchers.IO) { localEngine.loadModel(file.absolutePath) }
                activeModel = file
                modelPrefs.edit().putString("active_model_path", file.absolutePath).apply()
                modelText.text = "النموذج النشط: ${file.name}"
                statusText.text = "جاهز • ${formatSize(file.length())} • معالجة محلية"
                if (clearChat) {
                    messagesContainer.removeAllViews()
                    visibleConversation.clear()
                    addBubble("assistant", "تم تحميل ${file.name}. المحادثة الجديدة بدأت مع هذا النموذج.")
                }
            } catch (e: Exception) {
                if (activeModel == null) modelText.text = "ماكو نموذج محمّل حالياً"
                statusText.text = "فشل تحميل النموذج"
                toast("تعذر تحميل النموذج: ${e.message ?: "قد يكون كبيراً على الذاكرة المتاحة أو غير متوافق"}")
            } finally {
                isLoading = false
                setComposerEnabled(true)
            }
        }
    }

    private suspend fun awaitEngineReady(localEngine: InferenceEngine) {
        val state = localEngine.state.first {
            it is InferenceEngine.State.Initialized ||
                it is InferenceEngine.State.ModelReady ||
                it is InferenceEngine.State.Error
        }
        if (state is InferenceEngine.State.Error) throw state.exception
    }

    private fun resetConversation() {
        val file = activeModel
        if (file == null) {
            messagesContainer.removeAllViews()
            visibleConversation.clear()
            addBubble("assistant", "أضف نموذجاً أولاً حتى نبدأ محادثة جديدة.")
            return
        }
        AlertDialog.Builder(this)
            .setTitle("بدء محادثة جديدة")
            .setMessage("راح أعيد تحميل النموذج نفسه لمسح سياق المحادثة الحالي. قد يستغرق التحميل لحظات.")
            .setNegativeButton("إلغاء", null)
            .setPositiveButton("متابعة") { _, _ -> activateModel(file, clearChat = true) }
            .show()
    }

    /** Run a few predictable device actions; everything else goes to the local model. */
    private fun runPhoneCommand(original: String): Boolean {
        val command = original.trim().lowercase(Locale.ROOT)
        return when {
            command in listOf("افتح الإعدادات", "افتح الاعدادات", "افتح إعدادات الهاتف", "افتح اعدادات الهاتف") -> launchAction(Intent(Settings.ACTION_SETTINGS), "فتحت إعدادات الهاتف.")
            command in listOf("افتح الواي فاي", "افتح إعدادات الواي فاي", "افتح اعدادات الواي فاي") -> launchAction(Intent(Settings.ACTION_WIFI_SETTINGS), "فتحت إعدادات الواي فاي. التغيير النهائي يبقى بيدك من إعدادات النظام.")
            command in listOf("افتح البلوتوث", "افتح إعدادات البلوتوث", "افتح اعدادات البلوتوث") -> launchAction(Intent(Settings.ACTION_BLUETOOTH_SETTINGS), "فتحت إعدادات البلوتوث.")
            command in listOf("افتح إعدادات التطبيقات", "افتح اعدادات التطبيقات") -> launchAction(Intent(Settings.ACTION_APPLICATION_SETTINGS), "فتحت إعدادات التطبيقات.")
            command in listOf("افتح إعدادات الصوت", "افتح اعدادات الصوت") -> launchAction(Intent(Settings.ACTION_SOUND_SETTINGS), "فتحت إعدادات الصوت.")
            command in listOf("ارفع الصوت", "علي الصوت", "زود الصوت") -> adjustVolume(AudioManager.ADJUST_RAISE, "رفعت صوت الوسائط درجة واحدة.")
            command in listOf("خفض الصوت", "وطي الصوت", "نزل الصوت") -> adjustVolume(AudioManager.ADJUST_LOWER, "خفضت صوت الوسائط درجة واحدة.")
            command.startsWith("افتح تطبيق ") -> {
                val appName = original.substringAfter("افتح تطبيق ", "").trim()
                launchAppByName(appName)
            }
            command.startsWith("ابحث عن ") -> {
                val query = original.substringAfter("ابحث عن ", "").trim()
                if (query.isBlank()) false else {
                    val url = "https://www.google.com/search?q=" + URLEncoder.encode(query, "UTF-8")
                    launchAction(Intent(Intent.ACTION_VIEW, Uri.parse(url)), "فتحت المتصفح للبحث عن: $query")
                }
            }
            command.startsWith("اتصل بـ ") || command.startsWith("اتصل ب ") -> {
                val number = original.substringAfter(if (command.startsWith("اتصل بـ ")) "اتصل بـ " else "اتصل ب ").trim()
                if (number.isBlank()) false else launchAction(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", number, null)), "فتحت تطبيق الاتصال. راجع الرقم واضغط اتصال بنفسك.")
            }
            command in listOf("شغل الفلاش", "شغّل الفلاش", "اطفئ الفلاش", "طفي الفلاش") -> {
                val wanted = command in listOf("شغل الفلاش", "شغّل الفلاش")
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == android.content.pm.PackageManager.PERMISSION_GRANTED) setTorch(wanted)
                else {
                    requestedTorchState = wanted
                    askForCamera.launch(Manifest.permission.CAMERA)
                }
                addBubble("assistant", if (wanted) "طلبت تشغيل الفلاش." else "طلبت إطفاء الفلاش.")
                true
            }
            else -> false
        }
    }

    private fun launchAction(intent: Intent, successMessage: String): Boolean {
        return try {
            startActivity(intent)
            if (successMessage.isNotBlank()) addBubble("assistant", successMessage)
            true
        } catch (e: ActivityNotFoundException) {
            addBubble("assistant", "هذا الخيار غير متوفر على جهازك.")
            true
        } catch (e: Exception) {
            addBubble("assistant", "تعذر تنفيذ الإجراء: ${e.message ?: "خطأ غير معروف"}")
            true
        }
    }

    private fun adjustVolume(direction: Int, message: String): Boolean {
        try {
            val audio = getSystemService(AUDIO_SERVICE) as AudioManager
            audio.adjustStreamVolume(AudioManager.STREAM_MUSIC, direction, AudioManager.FLAG_SHOW_UI)
            addBubble("assistant", message)
        } catch (e: Exception) {
            addBubble("assistant", "تعذر تغيير الصوت: ${e.message ?: "خطأ غير معروف"}")
        }
        return true
    }

    private fun launchAppByName(query: String): Boolean {
        val apps = getLauncherApps()
        val found = apps.firstOrNull { it.loadLabel(packageManager).toString().contains(query, true) }
        if (found == null) {
            addBubble("assistant", "ما لقيت تطبيق باسم «$query». افتح «أدوات الهاتف» ثم «فتح تطبيق» واختاره من القائمة.")
            return true
        }
        return try {
            val intent = packageManager.getLaunchIntentForPackage(found.activityInfo.packageName)
            if (intent != null) {
                startActivity(intent)
                addBubble("assistant", "فتحت تطبيق ${found.loadLabel(packageManager)}.")
            } else addBubble("assistant", "ما گدرت أفتح هذا التطبيق من النظام.")
            true
        } catch (e: Exception) {
            addBubble("assistant", "تعذر فتح التطبيق: ${e.message ?: "خطأ غير معروف"}")
            true
        }
    }

    private fun getLauncherApps(): List<ResolveInfo> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val result = packageManager.queryIntentActivities(intent, 0)
        return result.distinctBy { it.activityInfo.packageName }.sortedBy { it.loadLabel(packageManager).toString().lowercase(Locale.ROOT) }
    }

    private fun showPhoneTools() {
        val choices = arrayOf(
            "فتح تطبيق من الهاتف",
            "إعدادات الهاتف",
            "إعدادات الواي فاي",
            "إعدادات البلوتوث",
            "إعدادات الصوت",
            "رفع الصوت",
            "خفض الصوت",
            "تشغيل / إطفاء الفلاش",
            "البحث في الويب",
            "فتح لوحة الاتصال",
            "كتابة رسالة SMS",
            "إنشاء ملف ملاحظة",
            "مشاركة آخر رد من نَوْر"
        )
        AlertDialog.Builder(this)
            .setTitle("أدوات الهاتف")
            .setItems(choices) { _, index ->
                when (index) {
                    0 -> showInstalledApps()
                    1 -> launchAction(Intent(Settings.ACTION_SETTINGS), "")
                    2 -> launchAction(Intent(Settings.ACTION_WIFI_SETTINGS), "")
                    3 -> launchAction(Intent(Settings.ACTION_BLUETOOTH_SETTINGS), "")
                    4 -> launchAction(Intent(Settings.ACTION_SOUND_SETTINGS), "")
                    5 -> adjustVolume(AudioManager.ADJUST_RAISE, "رفعت صوت الوسائط.")
                    6 -> adjustVolume(AudioManager.ADJUST_LOWER, "خفضت صوت الوسائط.")
                    7 -> {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == android.content.pm.PackageManager.PERMISSION_GRANTED) changeTorch()
                        else askForCamera.launch(Manifest.permission.CAMERA)
                    }
                    8 -> askSearchQuery()
                    9 -> askPhoneNumber()
                    10 -> askSmsDetails()
                    11 -> askNoteText()
                    12 -> shareLastAnswer()
                }
            }
            .setNegativeButton("إغلاق", null)
            .show()
    }

    private fun showInstalledApps() {
        val apps = getLauncherApps()
        if (apps.isEmpty()) {
            toast("ما ظهرت تطبيقات قابلة للفتح.")
            return
        }
        val labels = apps.map { it.loadLabel(packageManager).toString() }.toTypedArray()
        AlertDialog.Builder(this)
            .setTitle("اختَر تطبيقاً")
            .setAdapter(ArrayAdapter(this, android.R.layout.simple_list_item_1, labels)) { _, index ->
                val item = apps[index]
                val launchIntent = packageManager.getLaunchIntentForPackage(item.activityInfo.packageName)
                if (launchIntent != null) launchAction(launchIntent, "تم فتح ${labels[index]}.")
                else toast("ما متوفر أمر تشغيل لهذا التطبيق.")
            }
            .setNegativeButton("إغلاق", null)
            .show()
    }

    private fun changeTorch() = setTorch(!torchEnabled)

    private fun setTorch(enabled: Boolean) {
        try {
            val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val id = cameraManager.cameraIdList.firstOrNull { cameraId ->
                cameraManager.getCameraCharacteristics(cameraId).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            } ?: run { toast("هذا الجهاز ما أعلن عن فلاش متاح."); return }
            cameraManager.setTorchMode(id, enabled)
            torchEnabled = enabled
            toast(if (torchEnabled) "الفلاش شغّال" else "الفلاش مطفأ")
        } catch (e: Exception) {
            toast("تعذر التحكم بالفلاش: ${e.message ?: "راجع إذن الكاميرا"}")
        }
    }

    private fun askSearchQuery() {
        val edit = EditText(this).apply { hint = "شنو تريد تبحث عنه؟"; setTextColor(textPrimary); setHintTextColor(textSecondary) }
        AlertDialog.Builder(this).setTitle("بحث في الويب").setView(edit)
            .setNegativeButton("إلغاء", null)
            .setPositiveButton("بحث") { _, _ ->
                val query = edit.text.toString().trim()
                if (query.isNotBlank()) {
                    val url = "https://www.google.com/search?q=" + URLEncoder.encode(query, "UTF-8")
                    launchAction(Intent(Intent.ACTION_VIEW, Uri.parse(url)), "فتحت المتصفح للبحث عن: $query")
                }
            }.show()
    }

    private fun askPhoneNumber() {
        val edit = EditText(this).apply {
            hint = "رقم الهاتف"
            inputType = android.text.InputType.TYPE_CLASS_PHONE
            setTextColor(textPrimary)
            setHintTextColor(textSecondary)
        }
        AlertDialog.Builder(this).setTitle("فتح لوحة الاتصال").setView(edit)
            .setMessage("التطبيق يفتح لوحة الاتصال فقط، ولا يجري مكالمة دون تدخلك.")
            .setNegativeButton("إلغاء", null)
            .setPositiveButton("متابعة") { _, _ ->
                val number = edit.text.toString().trim()
                if (number.isNotBlank()) launchAction(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", number, null)), "راجع الرقم ثم اضغط اتصال بنفسك.")
            }.show()
    }

    private fun askSmsDetails() {
        val box = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(20), dp(8), dp(20), 0) }
        val number = EditText(this).apply { hint = "رقم المستلم"; inputType = android.text.InputType.TYPE_CLASS_PHONE; setTextColor(textPrimary); setHintTextColor(textSecondary) }
        val body = EditText(this).apply { hint = "نص الرسالة"; minLines = 3; gravity = Gravity.TOP; setTextColor(textPrimary); setHintTextColor(textSecondary) }
        box.addView(number)
        box.addView(body)
        AlertDialog.Builder(this).setTitle("كتابة رسالة SMS").setView(box)
            .setMessage("راح تنفتح تطبيق الرسائل مع النص جاهز. أنت تقرر إذا ترسله.")
            .setNegativeButton("إلغاء", null)
            .setPositiveButton("فتح الرسائل") { _, _ ->
                val phone = number.text.toString().trim()
                val message = body.text.toString()
                if (phone.isNotBlank()) {
                    val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:${Uri.encode(phone)}")).putExtra("sms_body", message)
                    launchAction(intent, "فتحت تطبيق الرسائل. ما انرسلت الرسالة تلقائياً.")
                } else toast("اكتب رقم المستلم أولاً.")
            }.show()
    }

    private fun askNoteText() {
        val edit = EditText(this).apply {
            hint = "اكتب الملاحظة هنا…"
            minLines = 4
            gravity = Gravity.TOP
            setTextColor(textPrimary)
            setHintTextColor(textSecondary)
        }
        AlertDialog.Builder(this).setTitle("إنشاء ملاحظة").setView(edit)
            .setNegativeButton("إلغاء", null)
            .setPositiveButton("حفظ إلى ملف") { _, _ ->
                val text = edit.text.toString()
                if (text.isNotBlank()) {
                    pendingExportText = text
                    pendingExportName = "NOUR-note-${System.currentTimeMillis()}.txt"
                    exportFile.launch(pendingExportName)
                }
            }.show()
    }

    private fun copyText(text: String) {
        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("NOUR", text))
        toast("تم نسخ النص.")
    }

    private fun shareText(text: String) {
        try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
            }
            startActivity(Intent.createChooser(intent, "مشاركة النص"))
        } catch (e: Exception) {
            toast("تعذرت مشاركة النص.")
        }
    }

    private fun saveText(text: String) {
        pendingExportText = text
        pendingExportName = "NOUR-response-${System.currentTimeMillis()}.txt"
        exportFile.launch(pendingExportName)
    }

    private fun shareLastAnswer() {
        val last = visibleConversation.lastOrNull { it.role == "assistant" }?.text
        if (last.isNullOrBlank()) toast("ماكو رد حتى أشاركه.") else shareText(last)
    }

    private fun formatSize(bytes: Long): String {
        if (bytes < 1024L) return "$bytes B"
        val units = arrayOf("KB", "MB", "GB", "TB")
        var value = bytes.toDouble()
        var index = -1
        do { value /= 1024.0; index++ } while (value >= 1024.0 && index < units.lastIndex)
        return "${DecimalFormat("#,##0.0").format(value)} ${units[index]}"
    }

    private fun toast(message: String) = Toast.makeText(this, message, Toast.LENGTH_LONG).show()
    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    override fun onDestroy() {
        generationJob?.cancel()
        try { engine?.destroy() } catch (_: Exception) {}
        super.onDestroy()
    }
}
