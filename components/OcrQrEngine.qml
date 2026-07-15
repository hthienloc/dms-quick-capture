import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

QtObject {
    property var modal

    function runOcr() {
        if (!modal) return;
        modal.ocrRect = Qt.rect(0, 0, 0, 0);
        modal.currentTool = "ocr";
        if (modal.activeCanvas) modal.activeCanvas.requestPaint();
        if (typeof ToastService !== "undefined" && ToastService) {
            ToastService.showInfo(I18n.tr("OCR: Draw a rectangle on the image to scan"));
        }
    }

    function executeOcr() {
        if (!modal || !modal.bgImageSource) return;
        const r = modal.ocrRect;
        if (r.width < 10 || r.height < 10) {
            modal.ocrRect = Qt.rect(0, 0, 0, 0);
            if (modal.activeCanvas) modal.activeCanvas.requestPaint();
            return;
        }

        const cropOffsetX = modal.hasSelection ? modal.cropRect.x : 0;
        const cropOffsetY = modal.hasSelection ? modal.cropRect.y : 0;
        const ix = Math.round(r.x + cropOffsetX);
        const iy = Math.round(r.y + cropOffsetY);
        const iw = Math.round(r.width);
        const ih = Math.round(r.height);

        let bgPath = decodeURIComponent(modal.bgImageSource.toString());
        if (bgPath.startsWith("file://")) bgPath = bgPath.substring(7);
        const qIdx = bgPath.indexOf("?");
        if (qIdx !== -1) bgPath = bgPath.substring(0, qIdx);
        const ocrLang = "eng";

        const uniqueId = Date.now() + "_" + Math.floor(Math.random() * 1000000);
        const tempCropPath = "/tmp/dms_ocr_crop_" + uniqueId + ".png";
        Proc.runCommand("crop-ocr-temp", ["magick", bgPath, "-crop", iw + "x" + ih + "+" + ix + "+" + iy, tempCropPath], (stdout1, exitCode1) => {
            if (exitCode1 === 0) {
                Proc.runCommand("run-ocr", ["tesseract", tempCropPath, "-", "-l", ocrLang], (stdout2, exitCode2) => {
                    Proc.runCommand("cleanup-ocr-temp", ["rm", "-f", tempCropPath]);

                    if (exitCode2 === 0) {
                        const result = stdout2.trim();
                        if (result) {
                            DMSService.sendRequest("clipboard.copy", { "text": result }, function(response) {
                                if (typeof ToastService !== "undefined" && ToastService) {
                                    ToastService.showInfo(I18n.tr("OCR: %1 chars copied to clipboard").arg(result.length));
                                }
                            });
                        } else {
                            if (typeof ToastService !== "undefined" && ToastService) {
                                ToastService.showInfo(I18n.tr("OCR: No text detected"));
                            }
                        }
                    } else {
                        if (typeof ToastService !== "undefined" && ToastService) {
                            ToastService.showError(I18n.tr("OCR failed during text extraction"));
                        }
                    }
                    modal.currentTool = modal.lastActiveTool;
                    modal.ocrRect = Qt.rect(0, 0, 0, 0);
                    if (modal.activeCanvas) modal.activeCanvas.requestPaint();
                });
            } else {
                if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError(I18n.tr("OCR failed: Could not crop image"));
                }
                modal.currentTool = modal.lastActiveTool;
                modal.ocrRect = Qt.rect(0, 0, 0, 0);
                if (modal.activeCanvas) modal.activeCanvas.requestPaint();
            }
        });
    }

    function runQrScan() {
        if (!modal) return;
        modal.ocrRect = Qt.rect(0, 0, 0, 0);
        modal.currentTool = "qr";
        if (modal.activeCanvas) modal.activeCanvas.requestPaint();
        if (typeof ToastService !== "undefined" && ToastService) {
            ToastService.showInfo(I18n.tr("QR Scan: Draw a rectangle on the image to scan"));
        }
    }

    function executeQrScan() {
        if (!modal || !modal.bgImageSource) return;
        const r = modal.ocrRect;
        if (r.width < 10 || r.height < 10) {
            modal.ocrRect = Qt.rect(0, 0, 0, 0);
            if (modal.activeCanvas) modal.activeCanvas.requestPaint();
            return;
        }

        const cropOffsetX = modal.hasSelection ? modal.cropRect.x : 0;
        const cropOffsetY = modal.hasSelection ? modal.cropRect.y : 0;
        const ix = Math.round(r.x + cropOffsetX);
        const iy = Math.round(r.y + cropOffsetY);
        const iw = Math.round(r.width);
        const ih = Math.round(r.height);

        let bgPath = decodeURIComponent(modal.bgImageSource.toString());
        if (bgPath.startsWith("file://")) bgPath = bgPath.substring(7);
        const qIdx = bgPath.indexOf("?");
        if (qIdx !== -1) bgPath = bgPath.substring(0, qIdx);

        const uniqueId = Date.now() + "_" + Math.floor(Math.random() * 1000000);
        const tempCropPath = "/tmp/dms_qr_crop_" + uniqueId + ".png";
        Proc.runCommand("crop-qr-temp", ["magick", bgPath, "-crop", iw + "x" + ih + "+" + ix + "+" + iy, tempCropPath], (stdout1, exitCode1) => {
            if (exitCode1 === 0) {
                Proc.runCommand("run-qr-scan", ["zbarimg", "--raw", "-q", tempCropPath], (stdout2, exitCode2) => {
                    Proc.runCommand("cleanup-qr-temp", ["rm", "-f", tempCropPath]);

                    if (exitCode2 === 0) {
                        const result = stdout2.trim();
                        if (result) {
                            DMSService.sendRequest("clipboard.copy", { "text": result }, function(response) {
                                if (typeof ToastService !== "undefined" && ToastService) {
                                    ToastService.showInfo(I18n.tr("QR Decoded: Copied to clipboard"));
                                }
                            });
                        } else {
                            if (typeof ToastService !== "undefined" && ToastService) {
                                ToastService.showInfo(I18n.tr("QR Scan: No QR code detected"));
                            }
                        }
                    } else if (exitCode2 === 4) {
                        if (typeof ToastService !== "undefined" && ToastService) {
                            ToastService.showInfo(I18n.tr("QR Scan: No QR code detected"));
                        }
                    } else {
                        if (typeof ToastService !== "undefined" && ToastService) {
                            ToastService.showError(I18n.tr("QR Scan failed or command execution error"));
                        }
                    }
                    modal.currentTool = modal.lastActiveTool;
                    modal.ocrRect = Qt.rect(0, 0, 0, 0);
                    if (modal.activeCanvas) modal.activeCanvas.requestPaint();
                });
            } else {
                if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError(I18n.tr("QR Scan failed: Could not crop image"));
                }
                modal.currentTool = modal.lastActiveTool;
                modal.ocrRect = Qt.rect(0, 0, 0, 0);
                if (modal.activeCanvas) modal.activeCanvas.requestPaint();
            }
        });
    }
}
