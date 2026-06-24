.pragma library

function copyStrokeProperties(source, target) {
    if (source.text !== undefined) target.text = source.text;
    if (source.isMonospace !== undefined) target.isMonospace = source.isMonospace;
    if (source.fontFamily !== undefined) target.fontFamily = source.fontFamily;
    if (source.isBold !== undefined) target.isBold = source.isBold;
    if (source.isItalic !== undefined) target.isItalic = source.isItalic;
    if (source.isUnderline !== undefined) target.isUnderline = source.isUnderline;
    if (source.counter !== undefined) target.counter = source.counter;
    if (source.format !== undefined) target.format = source.format;
    if (source.hasBackground !== undefined) target.hasBackground = source.hasBackground;
    if (source.cornerRadius !== undefined) target.cornerRadius = source.cornerRadius;
    if (source.borderWidth !== undefined) target.borderWidth = source.borderWidth;
}
