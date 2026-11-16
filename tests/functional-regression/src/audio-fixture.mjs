/** A playable 16-bit mono PCM WAV with deterministic samples. */
export function syntheticWav(sample = 0) {
  const rate = 16000;
  const wav = Buffer.alloc(44 + rate * 2);
  wav.write('RIFF', 0);
  wav.writeUInt32LE(wav.length - 8, 4);
  wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(rate, 24);
  wav.writeUInt32LE(rate * 2, 28);
  wav.writeUInt16LE(2, 32);
  wav.writeUInt16LE(16, 34);
  wav.write('data', 36);
  wav.writeUInt32LE(wav.length - 44, 40);
  wav.fill(sample, 44);
  return wav;
}

export async function uploadVoice(request, token, filename, context, bytes) {
  const formData = new FormData();
  formData.set('context', context);
  formData.set('file', new Blob([bytes], { type: 'audio/wav' }), filename);
  return (await request('/api/media/upload', { method: 'POST', token, formData })).data;
}
