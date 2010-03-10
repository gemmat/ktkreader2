function toQueryParams(aString) {
  var match = aString.match(/([^?#]*)(#.*)?$/);
  if (!match) return {};
  var hash = {};
  var arr = match[1].split('&');
  for (var i = 0, len = arr.length; i < len; i++) {
    var pair = arr[i];
    if ((pair = pair.split('='))[0]) {
      var key = decodeURIComponent(pair.shift());
      var value = pair.length > 1 ? pair.join('=') : pair[0];
      if (value != undefined) value = decodeURIComponent(value);
      hash[key] = value;
    }
  }
  return hash;
}

function toQueryString(aObject) {
  var results = [];
  for (var i in aObject) {
    var key = encodeURIComponent(i), values = aObject[i];
    if (values) results.push(key + "=" + values);
  }
  return results.join('&');
}

function forEach(aArray, aProc) {
  for (var i = 0, len = aArray.length; i < len; i++) {
    aProc(aArray[i]);
  }
}