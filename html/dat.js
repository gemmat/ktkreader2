function edit(aId, aCmd) {
  $("res-content-p-" + aId).setAttribute("class", aCmd);
}

function showResponse(req) {
	//put returned XML in the textarea
  var xmlData = req.responseXML;
	$('content').innerHTML = xmlData.getElementsByTagName("dat")[0].textContent;
  var arr_title = xmlData.getElementsByTagName("title");
  var arr_id    = xmlData.getElementsByTagName("id");
  document.title = arr_title[1].textContent + " - " + arr_title[0].textContent + "板 - ktkreader2";
  var o = $H(document.location.search.toQueryParams());
  o.set("cache",1);
  elt = $("sort-dat");
  if (!o.get("sort")) {
    o.set("sort", 1);
    elt.setAttribute("href", "./dat.html?" + o.toQueryString());
    elt.textContent = "レスを並びかえる";
    o.unset("sort");
  } else {
    o.unset("sort");
    elt.setAttribute("href", "./dat.html?" + o.toQueryString());
    elt.textContent = "ふつうに並びかえる";
    o.set("sort", 1);
  }
  o.unset("dq");
  o.set("sq", arr_id[0].textContent);
  var elt = null;
  elt = $("breadcrumbs-subject");
  elt.setAttribute("href", "./subject.html?" + o.toQueryString());
  elt.textContent = arr_title[0].textContent + "板" + (o.get("ss") ? "(" + o.get("ss") + ")" : "");
  $("thread-title").textContent = arr_title[1].textContent;
}

function main(evt) {
  var o = $H(document.location.search.toQueryParams());
  o.set("format", "html");
	var myAjax = new Ajax.Request(
    "http://localhost/~teruaki/cgi-bin/dat.cgi",
		{
			method: 'get',
			parameters: o.toQueryString(),
			onComplete: showResponse
		});
  o.set("cache",1);
  var elt = $("sort-dat");
  if (!o.get("sort")) {
    o.set("sort", 1);
    elt.setAttribute("href", "./dat.html?" + o.toQueryString());
    elt.textContent = "レスを並びかえる";
    o.unset("sort");
  } else {
    o.unset("sort");
    elt.setAttribute("href", "./dat.html?" + o.toQueryString());
    elt.textContent = "ふつうに並びかえる";
    o.set("sort", 1);
  }
  o.unset("sq");
  elt = $("breadcrumbs-bbsmenu");
  elt.setAttribute("href", "./bbsmenu.html?" + o.toQueryString());
  elt.textContent = "メニュー" + (o.get("bs") ? "(" + o.get("bs") + ")" : "");
}

Event.observe(window, "load", main);


