var myEditor = null;
var myResize = null;
var Dom = YAHOO.util.Dom;
var Event = YAHOO.util.Event;
var editing = null;
var revertDataStack = [];

function revertDataStackPush(elt) {
  revertDataStack.push([elt, elt.innerHTML.toString()]);
  Dom.get('revert').disabled = false;
  Dom.get('revert-sample-text').innerHTML = "これに戻します→" + elt.innerHTML.substring(0,40) + "...";
}

function revertDataStackPop() {
  var p = revertDataStack.pop();
  if (!revertDataStack.length) {
    Dom.get('revert').disabled = true;
    Dom.get('revert-sample-text').innerHTML = '';
  } else {
    Dom.get('revert-sample-text').innerHTML = "これに戻します→" + revertDataStack[revertDataStack.length - 1][1].substring(0,40) + "...";
  }
  return p;
}

function textEdit(elt) {
  showEditor(elt);
  myEditor.setEditorHTML(elt.innerHTML);
  if (revertDataStack.length > 5) {
    revertDataStack.shift();
  }
  revertDataStackPush(elt);
  editing = elt;
}

function showEditor(elt) {
  Dom.setXY(myEditor.get('element_cont').get('element'), Dom.getXY(elt));
  Dom.setStyle(myEditor.get('element').previousSibling, 'visibility', 'visible');
  myEditor._setDesignMode('on');
}

function closeEditor() {
  if (editing) {
    myEditor.saveHTML();
    editing.innerHTML = myEditor.get('element').value + "<br/>";
    if (revertDataStack.length) {
      var p = revertDataStack[revertDataStack.length - 1];
      if (p[0] == editing && p[1] == editing.innerHTML) {
        revertDataStackPop();
      }
    }
    editing = null;
  }
  hideEditor();
}

function hideEditor() {
  Dom.setXY(myEditor.get('element_cont').get('element'), [-9999, -9999]);
  Dom.setStyle(myEditor.get('element').previousSibling, 'visibility', 'hidden');
}

function edit(aId, aCmd) {
  var elt = Dom.get("res-content-body-" + aId);
  if (aCmd == 'del' && Dom.getAttribute(elt, "class") == 'del') aCmd = 'rr';
  Dom.setAttribute(elt, "class", aCmd);
}

function showResponse(req) {
  Dom.setStyle('loading-image', 'display', 'none');
	//put returned XML in the textarea
  var xmlData = req.responseXML;
  var xmlDataDat = xmlData.getElementsByTagName("dat");
  if (!xmlDataDat.length) {
    var xmlDataError = xmlData.getElementsByTagName("error");
    Dom.get('content').innerHTML = xmlDataError[0].firstChild.data;
    return;
  }
  var xmlDataHost = xmlData.getElementsByTagName("host");
  var xmlDataPath = xmlData.getElementsByTagName("path");
  var xmlDataKey  = xmlData.getElementsByTagName("key");
  if (xmlDataHost.length && xmlDataPath.length && xmlDataKey.length) {
    var url = ['http://',
               xmlDataHost[0].firstChild.data,
               '/test/read.cgi/',
               xmlDataPath[0].firstChild.data,
               '/',
               xmlDataKey[0].firstChild.data,
               '/'].join('');
    Dom.get('go-to').setAttribute('href', url);
    Dom.get('rss').setAttribute('href', 'http://2ch2rss.dip.jp/rss.xml?url=' + url);
    Dom.get('qrcode').setAttribute('href',
                                   ['http://chart.apis.google.com/chart?cht=qr&chs=150x150&choe=Shift_JIS&chl=http://c.2ch.net/test/-/',
                                   xmlDataPath[0].firstChild.data,
                                   '/',
                                   xmlDataKey[0].firstChild.data,
                                    '/i'].join(''));
  }
	Dom.get('content').innerHTML = xmlDataDat[0].textContent || xmlDataDat[0].firstChild.data;
  var arr_title = xmlData.getElementsByTagName("title");
  var arr_id    = xmlData.getElementsByTagName("id");
  document.title = arr_title[1].firstChild.data + " - " + arr_title[0].firstChild.data + "板 - 2chまとめサイトエディター2.0";
  var o = toQueryParams(document.location.search);
  o.cache = 1;
  o.dq = false;
  o.sq = arr_id[0].firstChild.data;
  var elt = Dom.get("breadcrumbs-subject");
  Dom.setAttribute(elt, "href", "./subject.html?" + toQueryString(o));
  elt.innerHTML = arr_title[0].firstChild.data + "板" + (o.ss ? "(" + o.ss + ")" : "");
  Dom.get("thread-title").innerHTML = arr_title[1].firstChild.data;
}

function revert() {
  if (revertDataStack.length) {
    var p = revertDataStackPop();
    p[0].innerHTML = p[1];
  }
}

function output() {
  var nodes = Dom.getChildren(Dom.getFirstChild('content'));
  var arr = [];
  for (var i = 0, len = nodes.length; i < len; i++) {
    var res = nodes[i];
    var res_header  = res.firstChild;
    var res_content = res.lastChild;
    var res_content_body = res_content.firstChild;
    var res_content_body_class = Dom.getAttribute(res_content_body, 'class');
    if (res_content_body_class == 'del') continue;
    arr.push(res_header.innerHTML + '<br/>');
    arr.push('<div class="' + res_content_body_class + '">');
    arr.push(res_content_body.innerHTML);
    arr.push('</div>');
  }
  Dom.get('output-textarea').value = arr.join('\n');
  Dom.setStyle('output-container', 'display', '');
}

function main(evt) {
  var o = toQueryParams(document.location.search);
  o.format = "html";
  if (o.dq) {
	  var myAjax = YAHOO.util.Connect.asyncRequest('GET',
    cgiURL + "dat.cgi?" + toQueryString(o),
    {success: showResponse});
  };
  o.format = false;
  o.cache = 1;
  var elt = Dom.get("sort-dat");
  if (!o.sort) {
    o.sort = 1;
    Dom.setAttribute(elt, "href", "./dat.html?" + toQueryString(o));
    elt.innerHTML = "レスを並びかえる";
    o.sort = false;
  } else {
    o.sort = false;
    Dom.setAttribute(elt, "href", "./dat.html?" + toQueryString(o));
    elt.innerHTML = "レス順に戻す";
    o.sort = 1;
  }
  o.sq = false;
  o.dq = false;
  o.cache = false;
  elt = Dom.get("breadcrumbs-bbsmenu");
  Dom.setAttribute(elt, "href", "./bbsmenu.html?" + toQueryString(o));
  elt.innerHTML = "メニュー" + (o.bs ? "(" + o.bs + ")" : "");

  Dom.setStyle('output-container', 'display', 'none');

  myEditor = new YAHOO.widget.Editor('msgpost',
    {
      height: '300px',
      width: '600px',
      autoHeight: true,
      buttonType: 'advanced',
      toolbar: {
        buttons: [
          { group: 'group1', label: '',
            buttons: [
              { type: 'push', label: '字ふつう', value: 'mybutton0'},
              { type: 'push', label: '字デカめ', value: 'mybutton1'},
              { type: 'push', label: '字デカく', value: 'mybutton2'},
              { type: 'separator' },
              { type: 'spin', label: '14', value: 'fontsize', range: [ 9, 75 ], disabled: true },
              { type: 'separator' },
              { type: 'color', label: '色', value: 'forecolor', disabled: true },
              { type: 'separator' },
              { type: 'push', label: 'リンク', value: 'createlink', disabled: true },
              { type: 'separator' },
              { type: 'push', label: '画像', value: 'insertimage' },
              { type: 'separator' },
              { type: 'push', label: '保存', value: 'save'}
            ]
          }
        ]
      }
    }
  );
  //myEditor.STR_BEFORE_EDITOR
  myEditor.STR_CLOSE_WINDOW = "閉じる";
  myEditor.STR_CLOSE_WINDOW_NOTE = "Control + Shift + W でも閉じられます。";
  myEditor.STR_IMAGE_BORDER = "枠";
  myEditor.STR_IMAGE_BORDER_SIZE = "枠サイズ";
  myEditor.STR_IMAGE_BORDER_TYPE = "枠タイプ";
  //myEditor.STR_IMAGE_COPY
  myEditor.STR_IMAGE_URL = "アドレス";
  myEditor.STR_IMAGE_HERE = "http://";
  myEditor.STR_IMAGE_ORIG_SIZE = "元サイズ";
  myEditor.STR_IMAGE_PADDING = "ツメ";
  myEditor.STR_IMAGE_PROP_TITLE = "画像";
  myEditor.STR_IMAGE_SIZE = "サイズ";
  myEditor.STR_IMAGE_TEXTFLOW = "文の回りこみ";
  myEditor.STR_IMAGE_TITLE = "説明文";
  myEditor.STR_LINK_NEW_WINDOW = "新しいウィンドウで開く";
  myEditor.STR_LINK_PROP_REMOVE = "文からリンクを外す";
  myEditor.STR_LINK_PROP_TITLE = "リンク";
  myEditor.STR_LINK_TITLE = "説明文";
  myEditor.STR_LINK_URL = "リンク";
  //myEditor.STR_LOCAL_FILE_WARNING
  myEditor.STR_NONE = "なし";
  myEditor.on('toolbarLoaded', function() {
    this.toolbar.on('mybutton0Click', function(o) {
        this.execCommand('fontsize', '14px');
    }, myEditor, true);
    this.toolbar.on('mybutton1Click', function(o) {
        this.execCommand('fontsize', '16px');
    }, myEditor, true);
    this.toolbar.on('mybutton2Click', function(o) {
        this.execCommand('fontsize', '23px');
    }, myEditor, true);
    this.toolbar.on('saveClick', function(o) {
      closeEditor();
    }, myEditor, true);
  }, myEditor, true);
  myEditor.render();
}

Event.on(window, "load", main);


