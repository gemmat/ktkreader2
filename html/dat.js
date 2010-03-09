function showResponse(req) {
	//put returned XML in the textarea
  var xmlData = req.responseXML;
	$('content').innerHTML = xmlData.getElementsByTagName("dat")[0].textContent;
  var arr0 = xmlData.getElementsByTagName("title");
  document.title = arr0[1].textContent + " - " + arr0[0].textContent + "板 - ktkreader2";
  var arr1 = xmlData.getElementsByTagName("id");
  var o = {};
  var q = document.location.search.toQueryParams();
  o.cache = 1;
  o.q = arr1[0].textContent;
  if (q.s) o.s = q.s;
  var elt = $("breadcrumbs-subject");
  elt.setAttribute("href", "./subject.html?" + Object.toQueryString(o));
  elt.textContent = arr0[0].textContent + "板";
  $("thread-title").textContent = arr0[1].textContent;
}

function main(evt) {
  var o = document.location.search.toQueryParams();
  o.cache = 1;
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


