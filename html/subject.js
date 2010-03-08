var meta = null;

function formatTitle(elCell, oRecord, oColumn, oData) {
  elCell.innerHTML = ['<a href="',
                      'http://localhost/~teruaki/cgi-bin/dat.cgi?q=',
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
                      'http://localhost/~teruaki/cgi-bin/dat.cgi?dry=1&q=',
                      d.id,
                      '">ｷｬｯｼｭ</a>'].join('');
}

function parseQuery() {
  var s = document.location.search;
  var m_q = /q=(\d+)/.exec(s);
  var m_c = /cache=\d+/.test(s);
  if (!m_q) return false;
  return ["http://localhost/~teruaki/cgi-bin/subject.cgi?q=",
          m_q[1],
          m_c ? "&dry=1" : ""].join("");
}

YAHOO.util.Event.onContentReady("table-container", function() {
  var url = parseQuery();
  if (!url) return;
  var dataSource = new YAHOO.util.XHRDataSource(url);
  dataSource.responseType = YAHOO.util.XHRDataSource.TYPE_XML;
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
  var configs = {
    caption: "スレ一覧",
    paginator : new YAHOO.widget.Paginator({
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
    })
  };
  var dataTable = new YAHOO.widget.DataTable("table-container", columns, dataSource, configs);
});
