var meta = null;
var dataTable = null;

YAHOO.util.Event.onContentReady("table-container", function() {
  var dataSource = new YAHOO.util.XHRDataSource(cgiURL + "subject.cgi?");
  dataSource.responseType = YAHOO.util.XHRDataSource.TYPE_XML;
  dataSource.connXhrMode = "queueRequests";
  dataSource.useXPath = true;
  dataSource.responseSchema = {
    metaFields: {
      boardId: "/ktkreader2/board/id",
      boardTitle: "/ktkreader2/board/title",
      boardHost: "/ktkreader2/board/host",
      boardPath: "/ktkreader2/board/path",
      boardURL: "/ktkreader2/board/url"
    },
    resultNode: "subject",
    fields: [
      {key: "subjectId", locator: "id", parser: "number"},
      {key: "subjectTitle", locator: "title"},
      {key: "subjectRescount", locator: "rescount", parser: "number"},
      {key: "subjectSpeed", locator: "speed", parser: "number"},
      {key: "subjectCache", locator: "cache", parser: "number"},
      {key: "subjectKey", locator: "key", parser: "number"}
    ]
  };
  dataSource.doBeforeCallback = function (oRequest, oFullResponse, oParsedResponse) {
    var o = toQueryParams(document.location.search);
    meta = oParsedResponse.meta;
    document.title = meta.boardTitle + "板" + (o.ss ? "(" + o.ss + ")" : "") + " - 2chまとめサイトエディター2.0";
    Dom.getElementsBy(function(x) {return true;}, "caption", "table-container", function (x) {
      x.innerHTML = meta.boardTitle + "板" + (o.ss ? "(" + o.ss + ")" : "");
      });
    return oParsedResponse;
  };
  // 各列の設定
  var columns = [
    //{key: "id", label: "ID", sortable: true},
    {key: "subjectTitle", label: "スレ", formatter: formatSubjectTitle, sortable: true, resizable: true},
    {key: "subjectRescount", label: "レス数", formatter: "number", sortable: true, sortOptions: { defaultDir: YAHOO.widget.DataTable.CLASS_DESC }},
    {key: "subjectSpeed", label: "勢い", formatter: "number", sortable: true, sortOptions: { defaultDir: YAHOO.widget.DataTable.CLASS_DESC }},
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
  var configs = {
    caption: "○○板",
    initialRequest: toQueryString(o),
    paginator : paginator
  };
  dataTable = new YAHOO.widget.DataTable("table-container", columns, dataSource, configs);

  forEach(["sq", "bs", "ss"], function(cl) {
    if (!o[cl]) return;
    Dom.getElementsByClassName(cl, "input", null, function(x) {
      x.value = o[cl];
    });
  });
  o.cache = false;
  o.sq = false;
  o.dq = false;
  var elt = Dom.get("breadcrumbs-bbsmenu");
  elt.setAttribute("href", "./bbsmenu.html?" + toQueryString(o));
  elt.innerHTML = "メニュー" + (o.bs ? "(" + o.bs + ")" : "");
});
