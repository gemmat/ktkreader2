var Dom = YAHOO.util.Dom;
var Event = YAHOO.util.Event;
var dataTable = null;

function formatTitle(elCell, oRecord, oColumn, oData) {
  var o = toQueryParams(document.location.search);
  o.cache = false;
  o.sq = oRecord.getData().id;
  o.dq = false;
  o.ss = false;
  elCell.innerHTML = ['<a href="',
                      './subject.html?',
                      toQueryString(o),
                      '">',
                      oData,
                      '</a>'].join('');

}

function formatCache(elCell, oRecord, oColumn, oData) {
  if (oData == "0") return;
  var o = toQueryParams(document.location.search);
  o.cache = 1;
  o.sq = oRecord.getData().id;
  o.dq = false;
  o.ss = false;
  elCell.innerHTML = ['<a href="',
                      './subject.html?',
                      toQueryString(o),
                      '">',
                      'ｷｬｯｼｭ',
                      '</a>'].join('');

}

Event.onContentReady("table-container", function() {
  var dataSource = new YAHOO.util.XHRDataSource(cgiURL + "bbsmenu.cgi?");
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
    {key: "cache", label: "ｷｬｯｼｭ", formatter: formatCache, sortable: true, sortOptions: { defaultDir: YAHOO.widget.DataTable.CLASS_DESC }}
  ];
  var paginator = new YAHOO.widget.Paginator({
    rowsPerPage: 20,
    // use a custom layout for pagination controls
    template: "{PageLinks} {RowsPerPageDropdown} 件ずつ表示",
    // show all links
    pageLinks: YAHOO.widget.Paginator.VALUE_UNLIMITED,
    // use these in the rows-per-page dropdown
    rowsPerPageOptions: [20, 50, 100, 250, 500, 1000],
    // use custom page link labels
    pageLabelBuilder: function (page,paginator) {
      var recs = paginator.getPageRecords(page);
      return (recs[0] + 1) + ' - ' + (recs[1] + 1);
    }
  });
  var o = toQueryParams(document.location.search);
  o.dq = false;
  o.sq = false;
  o.ss = false;
  var configs = {
    caption: "メニュー",
    initialRequest: toQueryString(o),
    paginator: paginator
  };
  if (o["bs"]) {
    Dom.getElementsByClassName("bs", "input", null, function(x) {
      x.value = o["bs"];
    });
  };
  dataTable = new YAHOO.widget.DataTable("table-container", columns, dataSource, configs);
});

Event.on(window, 'load', function(e) {
  //var myLogReader = new YAHOO.widget.LogReader("myLogger");
});