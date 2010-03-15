var myEditor = null;
var myResize = null;
var Dom = YAHOO.util.Dom;
var Event = YAHOO.util.Event;
var editing = null;
var revertDataStack = [];

function textEdit(elt) {
  showEditor(elt);
  myEditor.setEditorHTML(elt.innerHTML);
  if (revertDataStack.length > 5) {
    revertDataStack.shift();
  }
  revertDataStack.push(elt.innerHTML.toString());
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
    editing.innerHTML = myEditor.get('element').value;
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
	//put returned XML in the textarea
  var xmlData = req.responseXML;
	Dom.get('content').innerHTML = xmlData.getElementsByTagName("dat")[0].textContent;
  var arr_title = xmlData.getElementsByTagName("title");
  var arr_id    = xmlData.getElementsByTagName("id");
  document.title = arr_title[1].textContent + " - " + arr_title[0].textContent + "板 - ktkreader2";
  Dom.setStyle('loading-image', 'display', 'none');
  var o = toQueryParams(document.location.search);
  o.cache = 1;
  elt = Dom.get("sort-dat");
  if (!o.sort) {
    o.sort = 1;
    Dom.setAttribute(elt, "href", "./dat.html?" + toQueryString(o));
    elt.textContent = "レスを並びかえる";
    o.sort = false;
  } else {
    o.sort = false;
    Dom.setAttribute(elt, "href", "./dat.html?" + toQueryString(o));
    elt.textContent = "レス順に戻す";
    o.sort = 1;
  }
  o.dq = false;
  o.sq = arr_id[0].textContent;
  var elt = null;
  elt = Dom.get("breadcrumbs-subject");
  Dom.setAttribute(elt, "href", "./subject.html?" + toQueryString(o));
  elt.textContent = arr_title[0].textContent + "板" + (o.ss ? "(" + o.ss + ")" : "");
  Dom.get("thread-title").textContent = arr_title[1].textContent;
}

function output() {
  var nodes = Dom.get('content').firstChild.childNodes;
  var arr = ['<div class="main">'];
  for (var i = 0, len = nodes.length; i < len; i++) {
    var res = nodes[i];
    var res_header  = res.firstChild;
    var res_content = res.lastChild;
    var res_content_body = res_content.firstChild;
    arr.push(res_header.innerHTML);
    arr.push('<br/>');
    arr.push('<div class="' + Dom.getAttribute(res_content_body, 'class') + '">');
    arr.push(res_content_body.innerHTML);
    arr.push('</div>');
  }
  arr.push('</div>');
  Dom.get('output-textarea').value = arr.join('\n');
  Dom.setStyle('output-container', 'display', '');
}

function main(evt) {
  var o = toQueryParams(document.location.search);
  o.format = "html";
  if (o.dq) {
	  var myAjax = YAHOO.util.Connect.asyncRequest('GET',
    "http://localhost/~teruaki/cgi-bin/dat.cgi?" + toQueryString(o),
    {success: showResponse});
  };
  o.cache = 1;
  o.sq = false;
  var elt = Dom.get("breadcrumbs-bbsmenu");
  Dom.setAttribute(elt, "href", "./bbsmenu.html?" + toQueryString(o));
  elt.textContent = "メニュー" + (o.bs ? "(" + o.bs + ")" : "");

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
              { type: 'push', label: '元に戻す', value: 'revert'},
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
    Dom.setStyle(document.getElementsByClassName('yui-toolbar-separator-5')[0], 'width', '50px');
    Dom.setStyle(document.getElementsByClassName('yui-toolbar-separator-6')[0], 'width', '20px');
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
    this.toolbar.on('revertClick', function(o) {
      if (revertDataStack.length) {
        myEditor.setEditorHTML(revertDataStack.pop());
      }
    }, myEditor, true);
  }, myEditor, true);
  myEditor.render();
}

Event.on(window, "load", main);


