#target photoshop

function main() {
    if (app.documents.length === 0) {
        alert("No document open.");
        return;
    }

    var doc = app.activeDocument;
    var docName = doc.name.replace(/\.[^\.]+$/, '');
    
    var exportFolder = Folder.selectDialog("Select a folder to export assets and XML:");
    if (!exportFolder) return;

    var skinsFolder = new Folder(exportFolder + "/skins");
    if (!skinsFolder.exists) skinsFolder.create();

    var docWidth = doc.width.as("px");
    var docHeight = doc.height.as("px");

    var textureCache = {};
    var usedIds = {};
    var usedObjectIds = {};
    var objectNodes = [];
    var usedFonts = {};

    processLayers(doc.layers, skinsFolder, textureCache, objectNodes, docHeight, usedFonts, usedIds, usedObjectIds);

    var xmlStr = '<?xml version="1.0" encoding="utf-8"?>\n';
    xmlStr += '<skinFile version="1.0" width="' + docWidth + '" height="' + docHeight + '" assetsPath="skins">\n';
    
    xmlStr += '    <textures>\n';
    var exportedTextures = {};
    for (var sig in textureCache) {
        if (textureCache.hasOwnProperty(sig)) {
            var t = textureCache[sig];
            if (!exportedTextures[t.id]) {
                xmlStr += '        <texture id="' + t.id + '" file="' + t.file + '" />\n';
                exportedTextures[t.id] = true;
            }
        }
    }
    xmlStr += '    </textures>\n\n';

    xmlStr += '    <fonts>\n';
    for (var fontId in usedFonts) {
        if (usedFonts.hasOwnProperty(fontId)) {
            var f = usedFonts[fontId];
            xmlStr += '        <font id="' + fontId + '" fntFile="' + f.name + f.size + '.fnt" texture="' + f.name + f.size + '.png" />\n';
        }
    }
    xmlStr += '    </fonts>\n\n';

    xmlStr += '    <!-- Start of SCENE  -->\n';
    xmlStr += '    <objects>\n';
    for (var j = 0; j < objectNodes.length; j++) {
        xmlStr += objectNodes[j];
    }
    xmlStr += '    </objects>\n\n';
    xmlStr += '</skinFile>';

    var xmlFile = new File(exportFolder + "/" + docName + ".xml");
    xmlFile.encoding = "UTF-8";
    xmlFile.open("w");
    xmlFile.write(xmlStr);
    xmlFile.close();

    alert("Export completed successfully!");
}

function processLayers(layers, skinsFolder, textureCache, objectNodes, docHeight, usedFonts, usedIds, usedObjectIds) {
    for (var i = layers.length - 1; i >= 0; i--) {
        var layer = layers[i];

        if (layer.typename === "LayerSet") {
            processLayers(layer.layers, skinsFolder, textureCache, objectNodes, docHeight, usedFonts, usedIds, usedObjectIds);
            continue;
        }

        var baseName = layer.name.replace(/ copy( \d+)?$/g, "");
        var sanitizedBaseName = baseName.replace(/[:\/\\*\?"<>\|]/g, "_");
        
        var bounds = layer.bounds;
        var x = parseInt(bounds[0].as("px"));
        var topY = parseInt(bounds[1].as("px"));
        var w = parseInt(bounds[2].as("px")) - x;
        var h = parseInt(bounds[3].as("px")) - topY;

        if (w <= 0 || h <= 0) continue;

        var isVisible = layer.visible ? "true" : "false";
        
        var layerOpacityNormalized = layer.opacity / 100.0;
        var reversedY = docHeight - (topY + h);

        if (layer.kind === LayerKind.TEXT) {
            var textItem = layer.textItem;
            var fontName = textItem.font;
            var fontSize = Math.round(textItem.size.as("pt"));
            var fontId = fontName + fontSize;
            
            usedFonts[fontId] = { name: fontName, size: fontSize };

            var calculatedAlpha = Math.round(layerOpacityNormalized * 255);
            var hexColor = "#FFFFFFFF"; 
            try {
                var pColor = textItem.color.rgb;
                hexColor = rgbToHexWithAlpha(pColor.red, pColor.green, pColor.blue, calculatedAlpha);
            } catch(e) {
                hexColor = rgbToHexWithAlpha(255, 255, 255, calculatedAlpha);
            }

            // Detect Horizontal Justification
            var hJustify = "left";
            try {
                switch (textItem.justification) {
                    case Justification.CENTER:
                    case Justification.CENTERJUSTIFIED:
                        hJustify = "center";
                        break;
                    case Justification.RIGHT:
                    case Justification.RIGHTJUSTIFIED:
                        hJustify = "right";
                        break;
                    default:
                        hJustify = "left";
                }
            } catch(e) {
                hJustify = "left";
            }

            // Detect Vertical Justification
            var vJustify = "top"; 
            try {
                // Check if text is a Paragraph/Box text layout container
                if (textItem.kind === TextType.PARAGRAPHTEXT) {
                    // ActionManager API check for paragraph vertical justification properties
                    var ref = new ActionReference();
                    ref.putProperty(charIDToTypeID('Prpr'), charIDToTypeID('Txt '));
                    ref.putEnumerated(charIDToTypeID('Lyr '), charIDToTypeID('Ordn'), charIDToTypeID('Trgt'));
                    var desc = executeActionGet(ref);
                    if (desc.hasKey(charIDToTypeID('Txt '))) {
                        var textDesc = desc.getObjectValue(charIDToTypeID('Txt '));
                        if (textDesc.hasKey(stringIDToTypeID('textStyleRange'))) {
                            var textStyleRange = textDesc.getList(stringIDToTypeID('textStyleRange'));
                            if (textStyleRange.count > 0) {
                                var firstRange = textStyleRange.getObjectValue(0);
                                if (firstRange.hasKey(stringIDToTypeID('textStyle'))) {
                                    var styleDesc = firstRange.getObjectValue(stringIDToTypeID('textStyle'));
                                    if (styleDesc.hasKey(stringIDToTypeID('verticalJustification'))) {
                                        var vjEnum = styleDesc.getEnumerationValue(stringIDToTypeID('verticalJustification'));
                                        var vjStr = typeIDToStringID(vjEnum);
                                        if (vjStr === "center") vJustify = "center";
                                        if (vjStr === "bottom") vJustify = "bottom";
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Point text handles alignment relative to its baseline layout transform anchor
                    vJustify = "bottom"; 
                }
            } catch(e) {
                vJustify = "bottom"; // Safe system fallback alignment
            }

            var textId = layer.name.replace(/[:\/\\*\?"<>\|]/g, "_");
            if (usedObjectIds[textId]) {
                var tCount = 2;
                while (usedObjectIds[textId + "_" + tCount]) tCount++;
                textId = textId + "_" + tCount;
            }
            usedObjectIds[textId] = true;

            var textStr = '        <text id="' + textId + '" font="' + fontId + '" text="' + textItem.contents + '"\n';
            textStr += '            screenRect="{{' + x + ', ' + reversedY + '}, {' + w + ', ' + h + '}}" hJustify="' + hJustify + '" vJustify="' + vJustify + '" visible="' + isVisible + '" textColor="' + hexColor + '" />\n\n';
            objectNodes.push(textStr);
        } else {
            var sig = sanitizedBaseName + "_" + w + "x" + h;
            var textureId;

            if (textureCache[sig]) {
                textureId = textureCache[sig].id;
            } else {
                textureId = sanitizedBaseName;
                if (usedIds[textureId]) {
                    textureId = sanitizedBaseName + "_" + w + "x" + h;
                }

                exportPngLayer(layer, textureId, skinsFolder);
                textureCache[sig] = { id: textureId, file: textureId + ".png" };
                usedIds[textureId] = true;
            }

            var opacityAttr = layerOpacityNormalized.toFixed(2).replace(/\.?0+$/, '');
            var quadId = layer.name.replace(/[:\/\\*\?"<>\|]/g, "_");
            if (usedObjectIds[quadId]) {
                var qCount = 2;
                while (usedObjectIds[quadId + "_" + qCount]) qCount++;
                quadId = quadId + "_" + qCount;
            }
            usedObjectIds[quadId] = true;

            var quadStr = '        <quad id="' + quadId + '" texture="' + textureId + '" screenRect="{{' + x + ', ' + reversedY + '}, {' + w + ', ' + h + '}}" visible="' + isVisible + '" opacity="' + opacityAttr + '" />\n\n';
            objectNodes.push(quadStr);
        }
    }
}

function exportPngLayer(layer, filename, folder) {
    var doc = app.activeDocument;
    var rememberState = doc.activeHistoryState;
    
    layer.copy();
    var width = layer.bounds[2] - layer.bounds[0];
    var height = layer.bounds[3] - layer.bounds[1];
    var newDoc = app.documents.add(width, height, doc.resolution, filename, NewDocumentMode.RGB, DocumentFill.TRANSPARENT);
    newDoc.paste();

    var saveFile = new File(folder + "/" + filename + ".png");
    var exportOptions = new ExportOptionsSaveForWeb();
    exportOptions.format = SaveDocumentType.PNG;
    exportOptions.PNG8 = false; 
    exportOptions.transparent = true;

    newDoc.exportDocument(saveFile, ExportType.SAVEFORWEB, exportOptions);
    newDoc.close(SaveOptions.DONOTSAVECHANGES);

    doc.activeHistoryState = rememberState;
}

function rgbToHexWithAlpha(r, g, b, a) {
    return "#" + componentToHex(r) + componentToHex(g) + componentToHex(b) + componentToHex(a);
}

function componentToHex(c) {
    var hex = Math.round(c).toString(16).toUpperCase();
    return hex.length == 1 ? "0" + hex : hex;
}

main();
