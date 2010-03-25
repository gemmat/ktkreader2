var Dom = YAHOO.util.Dom;
var Event = YAHOO.util.Event;

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
    var key = encodeURIComponent(i), values = encodeURIComponent(aObject[i]);
    if (aObject[i]) results.push(key + "=" + values);
  }
  return results.join('&');
}

function forEach(aArray, aProc) {
  for (var i = 0, len = aArray.length; i < len; i++) {
    aProc(aArray[i]);
  }
}

function formatBoardTitle(elCell, oRecord, oColumn, oData) {
  var o = toQueryParams(document.location.search);
  o.sq = oRecord.getData("boardId");
  o.cache = false;
  o.q = false;
  elCell.innerHTML = ['<a href="',
                      './subject.html?',
                      toQueryString(o),
                      '">',
                      oData,
                      '</a>'
                      ].join('');

}

function formatBoardCache(elCell, oRecord, oColumn, oData) {
  if (oData == "0") return;
  var o = toQueryParams(document.location.search);
  o.cache = 1;
  o.sq = oRecord.getData("boardId");
  o.dq = false;
  o.ss = false;
  elCell.innerHTML = ['<a href="',
                      './subject.html?',
                      toQueryString(o),
                      '">',
                      'ｷｬｯｼｭ',
                      '</a>'].join('');

}

function formatSubjectTitle(elCell, oRecord, oColumn, oData) {
  var o = toQueryParams(document.location.search);
  o.dq = oRecord.getData("subjectId");
  o.cache = false;
  o.q = false;
  elCell.innerHTML = ['<a href="',
                      './dat.html?',
                      toQueryString(o),
                      '">',
                      oData,
                      '</a>'
                      ].join('');

}

function formatSubjectMisc(elCell, oRecord, oColumn, oData) {
  var d = oRecord.getData();
  var host = meta && meta.boardHost ? meta.boardHost : d.boardHost;
  var path = meta && meta.boardPath ? meta.boardPath : d.boardPath;
  var url = ['http://',
             host,
             '/test/read.cgi/',
             path,
             '/',
             oData,
             '/'].join('');
  elCell.innerHTML = ['<a href="',
                      url,
                      '"><img class="misc-icon" src="go-to-small.gif" title="元スレ" alt="元スレ"/></a> ',
                      '<a href="',
                      'http://2ch2rss.dip.jp/rss.xml?url=',
                      url,
                      '"><img class="misc-icon" src="rss-small.gif" title="RSS" alt="RSS"/></a> ',
                      '<a href="',
                      'http://chart.apis.google.com/chart?cht=qr&chs=150x150&choe=Shift_JIS&chl=http://c.2ch.net/test/-/',
                      path,
                      '/',
                      oData,
                      '/i',
                      '"><img class="misc-icon" src="qrcode-small.gif" title="QRコード" alt="QRコード"/></a>'
                     ].join('');
}

function formatSubjectCache(elCell, oRecord, oColumn, oData) {
  var d = oRecord.getData();
  if (!d.subjectCache) return;
  var o = toQueryParams(document.location.search);
  o.cache = 1;
  o.dq = d.subjectId;
  o.sort = false;
  o.q = false;
  elCell.innerHTML = ['<a href="',
                      './dat.html?',
                      toQueryString(o),
                      '">ｷｬｯｼｭ</a>',
                      '&nbsp;&nbsp;',
                      '<a href="',
                      './dat.html?',
                      toQueryString(o),
                      '&sort=1',
                      '">ﾅﾗﾋﾞｶｴ</a>'
                     ].join('');
}

