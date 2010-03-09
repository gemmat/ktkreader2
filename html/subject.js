var meta = null;
var dataTable = null;

function formatTitle(elCell, oRecord, oColumn, oData) {
  elCell.innerHTML = ['<a href="',
                      './dat.html?q=',
                      oRecord.getData().id,
                      '">',
                      oData,
                      '</a>'].join('');

}

function formatMisc(elCell, oRecord, oColumn, oData) {
  if (!meta) return;
  var url = ['http://',
             meta.boardHost,
             '/test/read.cgi/',
             meta.boardPath,
             '/',
             oData,
             '/'].join('');
  elCell.innerHTML = ['<a href="',
                      url,
                      '"><img class="misc-icon" src="go-to-small.gif" title="元URL" alt="元URL"/></a> ',
                      '<a href="',
                      'http://2ch2rss.dip.jp/rss.xml?url=',
                      url,
                      '"><img class="misc-icon" src="rss-small.gif" title="RSS" alt="RSS"/></a> ',
                      '<a href="',
                      'http://chart.apis.google.com/chart?cht=qr&chs=150x150&choe=Shift_JIS&chl=http://c.2ch.net/test/-/',
                      meta.boardPath,
                      '/',
                      oData,
                      '/i',
                      '"><img class="misc-icon" src="qrcode-small.gif" title="QRコード" alt="QRコード"/></a>'
                     ].join('');
}

function formatCache(elCell, oRecord, oColumn, oData) {
  var d = oRecord.getData();
  if (!d.cache) return;
  elCell.innerHTML = ['<a href="',
                      './dat.html?cache=1&q=',
                      d.id,
                      '">ｷｬｯｼｭ</a>'].join('');
}

YAHOO.util.Event.onContentReady("table-container", function() {
  var dataSource = new YAHOO.util.XHRDataSource("http://localhost/~teruaki/cgi-bin/subject.cgi?");
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
      {key: "id", parser: "number"},
      "title",
      {key: "rescount", parser: "number"},
      {key: "cache", parser: "number"},
      "key"
    ]
  };
  dataSource.doBeforeCallback = function (oRequest, oFullResponse, oParsedResponse) {
    meta = oParsedResponse.meta;
    document.title = meta.boardTitle + "板 - ktkreader2";
    return oParsedResponse;
  };
  // 各列の設定
  var columns = [
    //{key: "id", label: "ID", sortable: true},
    {key: "title", label: "スレタイ", formatter: formatTitle, sortable: true, resizable: true},
    {key: "rescount", label: "レス数", formatter: "number", sortable: true, sortOptions: { defaultDir: YAHOO.widget.DataTable.CLASS_DESC }},
    {key: "cache", label: "ｷｬｯｼｭ", formatter: formatCache, sortable: true, sortOptions: { defaultDir: YAHOO.widget.DataTable.CLASS_DESC }},
    {key: "key", label: "その他", formatter: formatMisc, className: "column-misc"}
  ];
  var paginator = new YAHOO.widget.Paginator({
    rowsPerPage: 50,
    // use a custom layout for pagination controls
    template: "{PageLinks} {RowsPerPageDropdown} 件ずつ表示",
    // show all links
    pageLinks: YAHOO.widget.Paginator.VALUE_UNLIMITED,
    // use these in the rows-per-page dropdown
    rowsPerPageOptions: [50, 100, 250, 500, 1000, 2000],
    // use custom page link labels
    pageLabelBuilder: function (page,paginator) {
      var recs = paginator.getPageRecords(page);
      return (recs[0] + 1) + ' - ' + (recs[1] + 1);
    }
  });
  var o = toQueryParams(document.location.search);
  if (o.s) {
    var arr = document.getElementsByClassName("search");
    arr[0].value = o.s;
    arr[1].value = o.s;
  }
  if (o.q) {
    var arr = document.getElementsByClassName("hidden-q");
    arr[0].value = o.q;
    arr[1].value = o.q;
  }
  var configs = {
    caption: "スレメニュー",
    initialRequest: toQueryString({q: o.q, cache: o.cache, s: o.s}),
    paginator : paginator
  };
  dataTable = new YAHOO.widget.DataTable("table-container", columns, dataSource, configs);
});
