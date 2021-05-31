// 2014-20 - ntop.org

String.prototype.capitalizeSingleWord = function () {
    var uc = this.toUpperCase();

    if ((uc == "ASN") || (uc == "OS"))
	return (uc);
    else
	return this.charAt(0).toUpperCase() + this.slice(1);
}

String.prototype.capitalize = function () {
    var res = this.split(" ");

    for (var i in res) {
	res[i] = res[i].capitalizeSingleWord();
    }

    return (res.join(" "));
}

String.prototype.startsWith = function (string) {
    return (this.indexOf(string) === 0);
};

// "{0} to {1}".sformat(1, 10) -> "1 to 10"
String.prototype.sformat = function () {
    var args = arguments;
    return this.replace(/{(\d+)}/g, function (match, number) {
	return typeof args[number] != 'undefined'
	    ? args[number]
	    : match
	;
    });
};

if (typeof (String.prototype.contains) === "undefined") {
    String.prototype.contains = function (s) {
	return this.indexOf(s) !== -1;
    }
}

