const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fs = require("fs");
const { OpenAI } = require("openai");

admin.initializeApp();

// قراءة المفتاح من Environment Variable
const openaiKey = process.env.OPENAI_KEY;
const openai = new OpenAI({ apiKey: openaiKey });

exports.transcribeAudio = functions.https.onCall(async (data, context) => {
  try {
    const filePath = data.filePath;
    const bucket = admin.storage().bucket();
    const tempFile = `/tmp/temp_audio.m4a`;

    await bucket.file(filePath).download({ destination: tempFile });

    const transcription = await openai.audio.transcriptions.create({
      file: fs.createReadStream(tempFile),
      model: "whisper-1"
    });

    return { transcript: transcription.text };
  } catch (err) {
    console.error(err);
    throw new functions.https.HttpsError("internal", err.message);
  }
});
