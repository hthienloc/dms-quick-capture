.pragma library

function hexToRgb(hex) {
    if (!hex) return { r: 0.2, g: 0.5, b: 1 };
    const c = Qt.color(hex);
    return { r: c.r, g: c.g, b: c.b };
}

function drawStroke(ctx, stroke, options) {
    if (stroke.points.length === 0) return;

    const rgb = hexToRgb(stroke.color);

    if (stroke.tool === "pen") {
        ctx.strokeStyle = stroke.color;
        ctx.lineWidth = stroke.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.beginPath();
        ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
        for (var i = 1; i < stroke.points.length; i++) {
            ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
        }
        ctx.stroke();

    } else if (stroke.tool === "line") {
        ctx.strokeStyle = stroke.color;
        ctx.lineWidth = stroke.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        ctx.beginPath();
        ctx.moveTo(p0.x, p0.y);
        ctx.lineTo(p1.x, p1.y);
        ctx.stroke();

    } else if (stroke.tool === "highlighter") {
        ctx.strokeStyle = Qt.rgba(rgb.r, rgb.g, rgb.b, 0.4);
        ctx.lineWidth = stroke.width * 4;
        ctx.lineCap = options.roundHighlighter ? "round" : "square";
        ctx.lineJoin = options.roundHighlighter ? "round" : "miter";
        ctx.beginPath();
        ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
        for (var i = 1; i < stroke.points.length; i++) {
            ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
        }
        ctx.stroke();

    } else if (stroke.tool === "rect") {
        ctx.strokeStyle = stroke.color;
        ctx.lineWidth = stroke.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        const rx = Math.min(p0.x, p1.x);
        const ry = Math.min(p0.y, p1.y);
        const rw = Math.abs(p1.x - p0.x);
        const rh = Math.abs(p1.y - p0.y);
        const baseRadius = options.roundRect ? (options.cornerRadius + (stroke.width / 2)) : 0;
        const radius = Math.min(baseRadius, Math.min(rw, rh) / 2);

        ctx.beginPath();
        ctx.moveTo(rx + radius, ry);
        ctx.lineTo(rx + rw - radius, ry);
        ctx.arcTo(rx + rw, ry, rx + rw, ry + radius, radius);
        ctx.lineTo(rx + rw, ry + rh - radius);
        ctx.arcTo(rx + rw, ry + rh, rx + rw - radius, ry + rh, radius);
        ctx.lineTo(rx + radius, ry + rh);
        ctx.arcTo(rx, ry + rh, rx, ry + rh - radius, radius);
        ctx.lineTo(rx, ry + radius);
        ctx.arcTo(rx, ry, rx + radius, ry, radius);
        ctx.closePath();
        ctx.stroke();

    } else if (stroke.tool === "ellipse") {
        ctx.strokeStyle = stroke.color;
        ctx.lineWidth = stroke.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        const rx = Math.min(p0.x, p1.x);
        const ry = Math.min(p0.y, p1.y);
        const rw = Math.abs(p1.x - p0.x);
        const rh = Math.abs(p1.y - p0.y);

        if (rw > 0 && rh > 0) {
            ctx.save();
            ctx.beginPath();
            ctx.translate(rx + rw / 2, ry + rh / 2);
            ctx.scale(rw / 2, rh / 2);
            ctx.arc(0, 0, 1, 0, 2 * Math.PI);
            ctx.restore();
            ctx.stroke();
        }

    } else if (stroke.tool === "arrow") {
        ctx.strokeStyle = stroke.color;
        ctx.fillStyle = stroke.color;
        ctx.lineWidth = stroke.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        const dx = p1.x - p0.x;
        const dy = p1.y - p0.y;
        const len = Math.sqrt(dx * dx + dy * dy);

        if (len > 0) {
            const angle = Math.atan2(dy, dx);
            const spread = Math.PI / 7;
            const headLength = Math.max(15, stroke.width * 4);
            
            const shaftLength = Math.max(0, len - headLength * 0.8);
            const shaftEndX = p0.x + shaftLength * Math.cos(angle);
            const shaftEndY = p0.y + shaftLength * Math.sin(angle);

            ctx.beginPath();
            ctx.moveTo(p0.x, p0.y);
            ctx.lineTo(shaftEndX, shaftEndY);
            ctx.stroke();

            ctx.beginPath();
            ctx.moveTo(p1.x, p1.y);
            ctx.lineTo(p1.x - headLength * Math.cos(angle - spread), p1.y - headLength * Math.sin(angle - spread));
            ctx.lineTo(p1.x - headLength * Math.cos(angle + spread), p1.y - headLength * Math.sin(angle + spread));
            ctx.closePath();
            ctx.fill();
        }

    } else if (stroke.tool === "redact") {
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        const rx = Math.min(p0.x, p1.x);
        const ry = Math.min(p0.y, p1.y);
        const rw = Math.abs(p1.x - p0.x);
        const rh = Math.abs(p1.y - p0.y);
        const radius = options.roundRect ? Math.min(options.cornerRadius, Math.min(rw, rh) / 2) : 0;

        ctx.fillStyle = stroke.color;
        ctx.beginPath();
        ctx.moveTo(rx + radius, ry);
        ctx.lineTo(rx + rw - radius, ry);
        ctx.arcTo(rx + rw, ry, rx + rw, ry + radius, radius);
        ctx.lineTo(rx + rw, ry + rh - radius);
        ctx.arcTo(rx + rw, ry + rh, rx + rw - radius, ry + rh, radius);
        ctx.lineTo(rx + radius, ry + rh);
        ctx.arcTo(rx, ry + rh, rx, ry + rh - radius, radius);
        ctx.lineTo(rx, ry + radius);
        ctx.arcTo(rx, ry, rx + radius, ry, radius);
        ctx.closePath();
        ctx.fill();

    } else if (stroke.tool === "pixelate") {
        if (stroke.points.length >= 2) {
            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            const rx = Math.floor(Math.min(p0.x, p1.x));
            const ry = Math.floor(Math.min(p0.y, p1.y));
            const rw = Math.floor(Math.abs(p1.x - p0.x));
            const rh = Math.floor(Math.abs(p1.y - p0.y));

            if (rw > 2 && rh > 2) {
                ctx.save();
                ctx.beginPath();
                ctx.rect(rx, ry, rw, rh);
                ctx.clip();
                ctx.imageSmoothingEnabled = false;

                if (options.bgImageReady && options.bgImageItem) {
                    const blockSize = Math.max(8, Math.min(36, stroke.width * 3));
                    const sampleSize = Math.max(1, Math.round(blockSize / 5));
                    const imgW = options.bgImageItem.sourceSize.width;
                    const imgH = options.bgImageItem.sourceSize.height;
                    for (let y = ry; y < ry + rh; y += blockSize) {
                        for (let x = rx; x < rx + rw; x += blockSize) {
                            const bw = Math.min(blockSize, rx + rw - x);
                            const bh = Math.min(blockSize, ry + rh - y);
                            if (bw <= 0 || bh <= 0) continue;
                            let sx = Math.min(x + Math.floor(bw / 2), rx + rw - 1);
                            let sy = Math.min(y + Math.floor(bh / 2), ry + rh - 1);
                            sx = Math.max(0, Math.min(sx, Math.max(0, imgW - sampleSize)));
                            sy = Math.max(0, Math.min(sy, Math.max(0, imgH - sampleSize)));
                            ctx.drawImage(options.bgImageItem, sx, sy, sampleSize, sampleSize, x, y, bw, bh);
                        }
                    }
                }

                if (options.isCurrentStroke) {
                    ctx.strokeStyle = "rgba(255, 255, 255, 0.6)";
                    ctx.lineWidth = 1;
                    ctx.setLineDash([4, 4]);
                    ctx.strokeRect(rx, ry, rw, rh);
                }
                ctx.restore();
            }
        }

    } else if (stroke.tool === "stamp") {
        const pt = stroke.points[0];
        const radius = stroke.width * 5;
        const lum = 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b;
        const textColor = lum > 0.5 ? "#000000" : "#ffffff";

        ctx.fillStyle = stroke.color;
        ctx.beginPath();
        ctx.arc(pt.x, pt.y, radius, 0, 2 * Math.PI);
        ctx.fill();

        const fontSize = Math.round(radius * 1.2);
        const text = String(stroke.counter);
        ctx.fillStyle = textColor;
        ctx.font = "bold " + fontSize + "px sans-serif";
        ctx.textBaseline = "middle";
        ctx.textAlign = "left";
        const textW = ctx.measureText(text).width;
        ctx.fillText(text, pt.x - textW / 2, pt.y + Math.round(fontSize * 0.1));

    } else if (stroke.tool === "text") {
        const pt = stroke.points[0];
        ctx.fillStyle = stroke.color;
        
        let styleStr = "";
        if (stroke.isItalic) styleStr += "italic ";
        if (stroke.isBold) styleStr += "bold ";
        const fFamily = stroke.fontFamily || (stroke.isMonospace ? "monospace" : "sans-serif");
        
        ctx.font = styleStr + Math.round(stroke.width) + "px " + fFamily;
        ctx.textAlign = "left";
        ctx.textBaseline = "top";
        ctx.fillText(stroke.text, pt.x, pt.y);

        if (stroke.isUnderline) {
            const textWidth = ctx.measureText(stroke.text).width;
            ctx.strokeStyle = stroke.color;
            ctx.lineWidth = Math.max(1.5, Math.round(stroke.width * 0.08));
            ctx.beginPath();
            ctx.moveTo(pt.x, pt.y + stroke.width * 1.05);
            ctx.lineTo(pt.x + textWidth, pt.y + stroke.width * 1.05);
            ctx.stroke();
        }
    }
}
