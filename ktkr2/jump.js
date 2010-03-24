var meta = null;
var dataTable = null;

YAHOO.util.Event.onContentReady("table-container", function() {
  var dataSource = new YAHOO.util.XHRDataSource(cgiURL + "jump.cgi?");
  dataSource.responseType = YAHOO.util.XHRDataSource.TYPE_XML;
  dataSource.connXhrMode = "queueRequests";
  dataSource.useXPath = true;
  dataSource.responseSchema = {
    resultNode: "result",
    fields: [
      {key: "boardId",         locator: "board/id",               parser: "number"},
      {key: "boardTitle",      locator: "board/title"},
      {key: "boardHost",       locator: "board/host"},
      {key: "boardPath",       locator: "board/path"},
      {key: "subjectId",       locator: "board/subject/id",       parser: "number"},
      {key: "subjectTitle",    locator: "board/subject/title"},
      {key: "subjectRescount", locator: "board/subject/rescount", parser: "number"},
      {key: "subjectCache",    locator: "board/subject/cache",    parser: "number"},
      {key: "subjectKey",      locator: "board/subject/key",      parser: "number"}
    ]
  };
  // 各列の設定
  var columns = [
    {key: "boardTitle", label: "板", formatter: formatBoardTitle, sortable: true, resizable: true},
    {key: "subjectTitle", label: "スレ", formatter: formatSubjectTitle, sortable: true, resizable: true},
    {key: "subjectRescount", label: "レス数", formatter: "number", sortable: true, sortOptions: { defaultDir: YAHOO.widget.DataTable.CLASS_DESC }},
    {key: "subjectSpeed", label: "勢い", formatter: formatSubjectSpeed, sortable: true, sortOptions: { field: "subjectSpeed", sortFunction: sortBySubjectSpeed, defaultDir: YAHOO.widget.DataTable.CLASS_DESC }},
    {key: "subjectCache", label: "ｷｬｯｼｭ", formatter: formatSubjectCache, sortable: true, sortOptions: { defaultDir: YAHOO.widget.DataTable.CLASS_DESC}},
    {key: "subjectKey", label: "その他", formatter: formatSubjectMisc, className: "column-misc"}
  ];
  var paginator = new YAHOO.widget.Paginator({
    rowsPerPage: 20,
    // use a custom layout for pagination controls
    template: "{PageLinks} {RowsPerPageDropdown} 件ずつ表示",
    // show all links
    pageLinks: YAHOO.widget.Paginator.VALUE_UNLIMITED,
    // use these in the rows-per-page dropdown
    rowsPerPageOptions: [20, 50, 100, 250, 500, 1000, 2000],
    // use custom page link labels
    pageLabelBuilder: function (page,paginator) {
      var recs = paginator.getPageRecords(page);
      return (recs[0] + 1) + ' - ' + (recs[1] + 1);
    }
  });
  var o = toQueryParams(document.location.search);
  if (!o.q) return;
  var configs = {
    caption: "検索",
    initialRequest: toQueryString(o),
    paginator : paginator
  };
  dataTable = new YAHOO.widget.DataTable("table-container", columns, dataSource, configs);
  Dom.get("q").value = o.q;
});
