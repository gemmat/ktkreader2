var dataTable = null;

function formatTitle(elCell, oRecord, oColumn, oData) {
  elCell.innerHTML = ['<a href="',
                      './subject.html?q=',
                      oRecord.getData().id,
                      '">',
                      oData,
                      '</a>'].join('');

}

function formatCache(elCell, oRecord, oColumn, oData) {
  if (oData == "0") return;
  elCell.innerHTML = ['<a href="',
                      './subject.html?cache=1&q=',
                      oRecord.getData().id,
                      '">',
                      'ｷｬｯｼｭ',
                      '</a>'].join('');

}

YAHOO.util.Event.onContentReady("table-container", function() {
  var dataSource = new YAHOO.util.XHRDataSource("http://localhost/~teruaki/cgi-bin/bbsmenu.cgi?");
  dataSource.responseType = YAHOO.util.XHRDataSource.TYPE_XML;
  dataSource.connXhrMode = "queueRequests";
  dataSource.useXPath = true;
  dataSource.responseSchema = {
    resultNode: "board",
    fields: [
      {key: "id", parser: "number"},
      "title",
      "host",
      "path",
      "url",
      "cache"
    ]
  };
  // 各列の設定
  var columns = [
    //{key: "id", label: "ID", sortable: true},
    {key: "title", label: "板名", formatter: formatTitle, sortable: true, resizable: true},
    {key: "cache", label: "ｷｬｯｼｭ", formatter: formatCache, sortable: true}
  ];
  var o = toQueryParams(document.location.search);
  if (o.s) {
    var arr = document.getElementsByClassName("search");
    arr[0].value = o.s;
    arr[1].value = o.s;
  }
  var configs = {
    caption: "板メニュー",
    initialRequest: toQueryString({cache: o.cache, s: o.s}),
    renderLoopSize: 25
  };
  dataTable = new YAHOO.widget.DataTable("table-container", columns, dataSource, configs);
});
