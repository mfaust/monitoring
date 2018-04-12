$(document).ready(function() {

  var $data = monitoring_hosts();
  console.debug($data);
  var $table = $('#monitoring-hosts');

  $("#monitoring-hosts > tbody").html("");

  var trHTML = '';

  $.each($data, function(index, elem) {

    var hostname = elem.dns.short;
    var created = elem.status.created;
    var status = elem.status.status;

    trHTML += '<tr>';
    trHTML += '<td><span class="uk-icon-button" uk-icon="laptop"></span></td>';
    trHTML += '<td>' + hostname + '</td>';
    trHTML += '<td>' + toDate(created) + '</td>';
    trHTML += '<td>';
    trHTML += ' <a href="#" class="uk-icon-link" uk-icon="commenting" uk-tooltip="add annotation"></a>';
    trHTML += ' <a href="#" class="uk-icon-link uk-text-danger uk-padding-small" uk-icon="trash" uk-tooltip="delete host"></a>';
    trHTML += '</td>';
    trHTML += '</tr>';

    $table.append(trHTML);
  });
});

$(function () {

  $('#add-host-text').focus();
  $("#add-host-button").on("click", function(event) {

    event.preventDefault();

    var $a = $('#add-host-text').val();
//     var params = { host: $a }

//     console.debug($a);
//     console.debug(params);

    $.ajax({
      type: 'post',
      url: '/web/ajax/add-host/' + $a,
//       data: params,
      statusCode: {
        200: function() {
          notification( 'successful', 'success' )
        },
        409: function() {
          notification( 'already exists', 'primary' )
        },
        401: function() {
          notification( 'error (401)', 'danger' )
        },
        404: function() {
          notification( 'error (404)', 'danger' )
        }
      }
    });
    //$('#add-host-text').text(( $(this).serialize() ));
  });
});

function notification( message, status ) {

  UIkit.notification({
    message: message,
    status: status,
    pos: 'top-right',
    timeout: 5000
  });
}

function monitoring_hosts() {

  var json = '';

  $.ajax({
    type: 'get',
    cache: false,
    async: false,
    dataType: 'json',
    url: '/api/v2/host',
    success: function(d) {
      json = d;
    },
    statusCode: {
      200: function() { /*console.debug('200')*/ },
      401: function() { /*console.debug('401')*/ },
      404: function() { /*console.debug('404')*/ }
    }
  });

  return json;
}

function toDate(dateStr) {

  const [date, time] = dateStr.split(" ")
  const [year, month, day] = date.split("-")

  d = new Date(year, month, day)

  return pad(d.getDate()) + '.' + pad(d.getMonth()) + '.' + d.getFullYear();
}

function pad(n){return n<10 ? '0'+n : n}


