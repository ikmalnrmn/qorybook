// Jembatan tipis ke pdf.js untuk pembaca PDF versi web (lihat lib/services/pdf_renderer_web.dart).
// Meniru API pembaca native Android: open -> ukuran halaman, render -> JPEG, close.
(function () {
  const docs = new Map();
  let nextId = 1;
  const MAX_SIZED_PAGES = 200;

  window.qoryPdf = {
    // Mengembalikan {id, sizes: [w0, h0, w1, h1, ...]} dalam satuan point PDF.
    async open(url) {
      const pdfjs = window.pdfjsLib;
      if (!pdfjs) throw new Error('pdf.js belum dimuat');
      pdfjs.GlobalWorkerOptions.workerSrc = 'pdfjs/pdf.worker.min.js';
      const doc = await pdfjs.getDocument({ url, rangeChunkSize: 1 << 18, withCredentials: false }).promise;
      const count = doc.numPages;
      const sized = Math.min(count, MAX_SIZED_PAGES);
      const sizes = new Array(count * 2);
      const first = await doc.getPage(1);
      const base = first.getViewport({ scale: 1 });
      for (let i = 0; i < count; i++) {
        sizes[i * 2] = base.width;
        sizes[i * 2 + 1] = base.height;
      }
      // Ukuran tiap halaman bisa berbeda (sampul, halaman lipat); baca paralel dalam kelompok kecil.
      for (let start = 1; start < sized; start += 8) {
        const batch = [];
        for (let n = start + 1; n <= Math.min(start + 8, sized); n++) batch.push(doc.getPage(n));
        const pages = await Promise.all(batch);
        pages.forEach((page, k) => {
          const vp = page.getViewport({ scale: 1 });
          const idx = start + k;
          sizes[idx * 2] = vp.width;
          sizes[idx * 2 + 1] = vp.height;
        });
      }
      const id = nextId++;
      docs.set(id, doc);
      return { id, sizes };
    },

    // JPEG halaman [pageIndex] (mulai 0) selebar [widthPx] piksel.
    async render(id, pageIndex, widthPx) {
      const doc = docs.get(id);
      if (!doc) throw new Error('dokumen sudah ditutup');
      const page = await doc.getPage(pageIndex + 1);
      const base = page.getViewport({ scale: 1 });
      const viewport = page.getViewport({ scale: widthPx / base.width });
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.ceil(viewport.width));
      canvas.height = Math.max(1, Math.ceil(viewport.height));
      const ctx = canvas.getContext('2d', { alpha: false });
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      await page.render({ canvasContext: ctx, viewport }).promise;
      const blob = await new Promise((resolve, reject) =>
        canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('gagal membuat gambar'))), 'image/jpeg', 0.88),
      );
      page.cleanup();
      canvas.width = canvas.height = 0;
      return new Uint8Array(await blob.arrayBuffer());
    },

    close(id) {
      const doc = docs.get(id);
      docs.delete(id);
      if (doc) doc.destroy();
    },
  };
})();
