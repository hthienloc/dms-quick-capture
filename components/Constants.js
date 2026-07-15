.pragma library

// Configuration defaults
const defaultEditQuality = 720;
const defaultBackdropPadding = 40;
const defaultBackdropCornerRadius = 12;
const defaultBackdropShadowStrength = 50;
const defaultBackdropGradientAngle = 45;
const defaultBackdropAspectRatio = "auto";
const defaultBackdropMode = "solid";

// Selection and threshold constants
const selectionThresholdBase = 12;
const ocrSelectionPadding = 8;
const stampSelectThresholdOffset = 6;
const rectSelectionPadding = 5;
const calloutSelectionPadding = 5;
const minTextWidth = 40;

// Tool multipliers and scales
const lineDashMultiplier = 2.5;
const lineGapMultiplier = 1.5;
const dottedGapMultiplier = 2.0;
const highlighterScale = 4.0;
const stampRadiusMultiplier = 5.0;
const stampTextFontSizeMultiplier = 1.2;
const stampTextOffsetMultiplier = 0.1;
const textPaddingMultiplierX = 0.3;
const textPaddingMultiplierY = 0.15;

// Default radial menu preset tools
const defaultRadialTools = ["pen", "arrow", "rect", "highlighter", "ellipse", "stamp", "redact", "pixelate"];

// Selection resize handles
const selectionHandleSize = 8;
