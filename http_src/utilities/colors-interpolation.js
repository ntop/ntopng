/**
    (C) 2022 - ntop.org    
*/

function transformColors(colors) {
    let colorsPositionDict = {};
    colors.forEach((c, i) => {
	if (colorsPositionDict[c] == null) {
	    colorsPositionDict[c] = [i];
	} else {
	    colorsPositionDict[c].push(i);
	}
    });
    // clone colors
    let newColors = ntopng_utility.clone(colors);
    
    for (let color in colorsPositionDict) {
	let colorsPosition = colorsPositionDict[color];
	let n = colorsPosition.length;
	// colorsGenerated.length == colorsPosition.length always true
	let colorsGenerated = getColorsFromColor(color, n);
	colorsGenerated.forEach((c, i) => {
	    let cPosition = colorsPosition[i];
	    newColors[cPosition] = c;
	});
    }
    return newColors;
}

function getColorsFromColor(color, n) {
    return [...Array(n).keys()].map((c, i) => {
	return generateColor(color, i + 1, n);
    });
}

/**
 * Generate a color that represent the index-th tint of n of baseColor.
 * @param {baseColor} string color in hex format.
 * @param {index} integer in interval [1, n].
 * @param {n} total number of colors to generate
**/
function generateColor(baseColor, index, n) {
    let sourceColor = baseColor.replace("#", "");

    let redSource = parseInt(sourceColor.substring(0, 2), 16);
    let greenSource = parseInt(sourceColor.substring(2, 4), 16);
    let blueSource = parseInt(sourceColor.substring(4, 6), 16);

    let cRed = getColorInterpolation(redSource, index, n);
    let cGreen = getColorInterpolation(greenSource, index, n);
    let cBlue = getColorInterpolation(blueSource, index, n);

    return rgbToHex(cRed, cGreen, cBlue);
}

function getColorInterpolation(colorSource, i, n) {    
    if (n <= 1) {
	return colorSource;
    }
    let colorStart = Math.trunc(colorSource / 2);
    let colorEnd = Math.trunc(colorSource + ((255 - colorSource) / 2));
    let interval = Math.trunc((colorEnd - colorStart) / n);

    return colorStart + i * interval;
    // return colorStart + (n - i) * interval;
}

function rgbToHex(r, g, b) {
    return "#" + componentToHex(r) + componentToHex(g) + componentToHex(b);
}

function componentToHex(c) {
    let hex = c.toString(16);
    return hex.length == 1 ? "0" + hex : hex;
}

const colorsInterpolation = function() {
    return {
	transformColors,
    };
}();

export default colorsInterpolation;
