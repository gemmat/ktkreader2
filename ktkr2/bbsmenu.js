var dataTable = null;

Event.onContentReady("table-container", function() {
  var dataSource = new YAHOO.util.XHRDataSource(cgiURL + "bbsmenu.cgi?");
  dataSource.responseType = YAHOO.util.XHRDataSource.TYPE_XML;
  dataSource.connXhrMode = "queueRequests";
  dataSource.useXPath = true;
  dataSource.responseSchema = {
    resultNode: "board",
    fields: [
      {key: "boardId", locator: "id", parser: "number"},
      {key: "boardTitle", locator: "title"},
      {key: "boardHost", locator: "host"},
      {key: "boardPath", locator: "path"},
      {key: "boardCache", locator: "cache", parser: "number"}
    ]
  };
  // 各列の設定
  var columns = [
    //{key: "id", label: "ID", sortable: true},
    {key: "boardTitle", label: "板名", formatter: formatBoardTitle, sortable: true, resizable: true},
    {key: "boardCache", label: "ｷｬｯｼｭ", formatter: formatBoardCache, sortable: true, sortOptions: { defaultDir: YAHOO.widget.DataTable.CLASS_DESC }}
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

//Event.on(window, 'load', function(e) {
  //var myLogReader = new YAHOO.widget.LogReader("myLogger");
//});