.pragma library

// Configuration defaults
const defaultEditPixelBudget = 300000;
const defaultBackgroundPadding = 40;
const defaultBackgroundCornerRadius = 12;
const defaultBackgroundShadowStrength = 0;
const defaultBackgroundGradientAngle = 45;
const defaultBackgroundAspectRatio = "auto";
const defaultBackgroundMode = "solid";
const defaultBackgroundAlignment = "center";

// Selection and threshold constants
const selectionThresholdBase = 12;
const ocrSelectionPadding = 8;
const stampSelectThresholdOffset = 6;
const rectSelectionPadding = 5;
const calloutSelectionPadding = 5;

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

// Tool intensity metadata
// Each tool defines: min, max, step, unit, default, and optional multipliers
const ToolMetadata = {
    pen: {
        min: 1,
        max: 50,
        step: 1,
        unit: "px",
        defaultValue: 8,
        label: "Thickness",
        previewType: "thickness"
    },
    line: {
        min: 1,
        max: 50,
        step: 1,
        unit: "px",
        defaultValue: 8,
        label: "Thickness",
        previewType: "thickness"
    },
    arrow: {
        min: 1,
        max: 50,
        step: 1,
        unit: "px",
        defaultValue: 8,
        label: "Thickness",
        previewType: "thickness"
    },
    rect: {
        min: 1,
        max: 50,
        step: 1,
        unit: "px",
        defaultValue: 8,
        label: "Thickness",
        previewType: "thickness"
    },
    ellipse: {
        min: 1,
        max: 50,
        step: 1,
        unit: "px",
        defaultValue: 8,
        label: "Thickness",
        previewType: "thickness"
    },
    highlighter: {
        min: 1,
        max: 50,
        step: 1,
        unit: "px",
        defaultValue: 8,
        label: "Thickness",
        previewType: "thickness",
        previewMultiplier: 4
    },
    redact: {
        min: 1,
        max: 50,
        step: 1,
        unit: "px",
        defaultValue: 8,
        label: "Thickness",
        previewType: "thickness"
    },
    stamp: {
        min: 1,
        max: 50,
        step: 1,
        unit: "px",
        defaultValue: 8,
        label: "Stamp Size",
        previewType: "thickness",
        previewMultiplier: 10
    },
    text: {
        min: 12,
        max: 120,
        step: 1,
        unit: "px",
        defaultValue: 36,
        label: "Font Size",
        previewType: "none"
    },
    pixelate: {
        min: 2,
        max: 16,
        step: 1,
        unit: "px",
        defaultValue: 8,
        label: "Pixel Intensity",
        previewType: "none",
        previewMultiplier: 3,
        previewClampMin: 8,
        previewClampMax: 48
    },
    spotlight: {
        min: 10,
        max: 100,
        step: 1,
        unit: "%",
        defaultValue: 50,
        label: "Dimming Opacity",
        previewType: "none",
        previewFixedWidth: 100
    },
    callout: {
        min: 100,
        max: 500,
        step: 10,
        unit: "%",
        defaultValue: 150,
        label: "Zoom Level",
        previewType: "none",
        previewFixedWidth: 40,
        borderWidthMin: 1,
        borderWidthMax: 10
    }
};

function getToolMeta(tool) {
    return ToolMetadata[tool] || ToolMetadata.pen;
}

// Default radial menu preset tools
const defaultRadialTools = ["pen", "arrow", "rect", "highlighter", "ellipse", "stamp", "redact", "pixelate"];
const defaultRadialColors = ["primary", "primary", "primary", "primary", "primary", "primary", "#000000", "#ffffff"];

// Selection resize handles
const selectionHandleSize = 12;

// Text speech bubble configuration
const textBubblePaddingMultiplierX = 0.5;
const textBubblePaddingMultiplierY = 0.3;
const textBubbleDefaultRadius = 8;
const textBubbleMinRadius = 8;
const textBubbleDragThreshold = 10;

// Shadow rendering constants
const defaultShadowSteps = 24;
const maxShadowOffset = 24.0;
const maxShadowBlur = 45.0;
const shadowBaseOpacityFactor = 0.55;

// Magnifier Loupe sizing
const magnifierSize = 160;
const magnifierCrosshairSize = 16;
const magnifierBannerHeight = 56;
const magnifierSwatchSize = 20;
const magnifierSwatchRadius = 5;

// Toolbar sizing constants (from ToolbarConstants.qml)
const btnSize = 36;
const iconSize = 18;
const btnSizeCompact = 28;
const iconSizeCompact = 14;
const spacingCompact = 2;
const fontSizeCompact = 9;
const separatorThickness = 1;
const separatorLength = 24;
const gridSpacing = 4;
const backgroundIconSize = 16;
const sliderWidth = 100;
const swatchSize = 20;
const swatchRadius = 10;
const swatchSizeVert = 18;
const swatchRadiusVert = 9;
const presetBtnWidth = 44;
const presetBtnHeight = 24;
const presetFontSize = 10;
const popoverHeight = 72;
const subToolbarHeight = 48;
const subToolbarBtnSize = 36;
const subToolbarIconSize = 20;
const compactControlHeight = 40;
const customRatioPopoverHeight = 120;
const verticalSelectorItemWidth = 32;

// Text rendering constants
const textLineHeightMultiplier = 1.35;  // line-height relative to font size

// Callout auto-placement constants
const calloutAutoPlacementMargin = 50;  // px gap from source rect when auto-placing callout dest
const fallbackCanvasWidth = 1920;       // used when canvasWidth is not passed in render config
const fallbackCanvasHeight = 1080;      // used when canvasHeight is not passed in render config

// Default Background Presets
const defaultBackgroundPresets = [
    {
        id: "studio_dark",
        name: "Studio Dark",
        mode: "solid",
        solidColor: "#1e1e2e",
        gradientStart: "#1e1e2e",
        gradientEnd: "#181825",
        gradientAngle: 45,
        padding: 40,
        cornerRadius: 16,
        shadowStrength: 50,
        aspectRatio: "auto",
        customAspectRatio: 1.50
    }
];
