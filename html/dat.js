function showResponse(req) {
	//put returned XML in the textarea
  var xmlData = req.responseXML;
	$('content').innerHTML = xmlData.getElementsByTagName("dat")[0].textContent;
  var arr0 = xmlData.getElementsByTagName("title");
  document.title = arr0[1].textContent + " - " + arr0[0].textContent + "板 - ktkreader2";
  var o = $H(document.location.search.toQueryParams());
  o.set("cache",1);
  o.unset("dq");
  var elt = null;
  elt = $("breadcrumbs-subject");
  elt.setAttribute("href", "./subject.html?" + o.toQueryString());
  elt.textContent = arr0[0].textContent + "板" + (o.get("ss") ? "(" + o.get("ss") + ")" : "");
  o.unset("sq");
  elt = $("breadcrumbs-bbsmenu");
  elt.setAttribute("href", "./bbsmenu.html?" + Object.toQueryString(o));
  elt.textContent = "メニュー" + (o.get("bs") ? "(" + o.get("bs") + ")" : "");
  $("thread-title").textContent = arr0[1].textContent;
}

function main(evt) {
  var o = document.location.search.toQueryParams();
  o.format = "html";
	var myAjax = new Ajax.Request(
    "http://localhost/~teruaki/cgi-bin/dat.cgi",
		{
			method: 'get',
			parameters: Object.toQueryString(o),
			onComplete: showResponse
		});
}

Event.observe(window, "load", main);


