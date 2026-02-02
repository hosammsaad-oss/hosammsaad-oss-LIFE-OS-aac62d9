const functions = require("firebase-functions");
const express = require("express");
const multer = require("multer");
const cors = require("cors");
const fs = require("fs");
const OpenAI = require("openai");

// Init Express
const app = express();
app.use(cors());
const upload = multer({ dest: "uploads/" });

// Init OpenAI
const openai = new OpenAI({
  apiKey: functions.config().openai.key, // سنضبط المفتاح لاحقًا
});

// Endpoint لتحليل الصوت
app.post("/analyze", upload.single("audio"), async (req, res) => {
  try {
    const audioPath = req.file.path;

    // Whisper: تحويل الصوت إلى نص
    const transcription = await openai.audio.transcriptions.create({
      file: fs.createReadStream(audioPath),
      model: "whisper-1",
    });

    const text = transcription.text;

    // GPT: استخراج Summary, Tasks, Decisions
    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: "Extract meeting summary, tasks, and decisions into JSON only.",
        },
        {
          role: "user",
          content: `
From the following meeting text extract:
- summary
- tasks
- decisions

Return strict JSON:
{
  "summary": "",
  "tasks": [],
  "decisions": []
}

Text:
${text}
          `,
        },
      ],
    });

    fs.unlinkSync(audioPath); // حذف الملف بعد التحليل

    const result = completion.choices[0].message.content;
    res.json(JSON.parse(result));
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Analysis failed" });
  }
});

// Export as Firebase Function
exports.api = functions.https.onRequest(app);
