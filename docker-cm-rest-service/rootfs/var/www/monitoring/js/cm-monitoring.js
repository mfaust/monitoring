$(document).ready(function() {

  var $data = monitoring_hosts();
  var $table = $('#monitoring-hosts');
  var trHTML = '';

  $("#monitoring-hosts > tbody").html("");

  console.debug($data);

  $.each($data, function(index, elem) {

    console.debug('index ' + index);
    console.debug('elem  ' + elem);

    if(index === 'status') {
      // return false; //this is equivalent of 'break' for jQuery loop
      return; //this is equivalent of 'continue' for jQuery loop
    }

    if(elem === undefined) {
      console.debug('elem are undef')
      return;
    }
    if(elem.dns === undefined) {
      console.debug('elem.dns are undef')
      console.debug(elem)
      return;
    }

    trHTML += '<tr data-hostname="'+elem.dns.short+'">';
    trHTML += '<td><span class="uk-icon-button" uk-icon="laptop"></span></td>';
    trHTML += '<td>' + elem.dns.short + '</td>';
    trHTML += '<td>' + toDate(elem.status.created) + '</td>';
    trHTML += '<td>';
    trHTML += ' <a href="#" class="uk-icon-link add-annotation" uk-icon="commenting" uk-tooltip="add annotation"></a>';
    trHTML += ' <a href="#" class="uk-icon-link delete-host uk-text-danger uk-padding-small" uk-icon="trash" uk-tooltip="delete host"></a>';
    trHTML += '</td>';
    trHTML += '</tr>';

    $table.append(trHTML);
  });
});

$(function() {

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

$(function() {

  var $table = $('#monitoring-hosts');

  $table.on('click', '.add-annotation', function() {

    var $t = $(this)
    var $b = $t.closest('tr');
    var $hostname = $b.data('hostname');
    //var $m = $t.find( '.msg-wrap' );
    //var $e = $t.find( '.msg-edit' );

    console.debug($t);
    console.debug($hostname);
  });

  $('.add-annotation').on('click', function(event) {

    UIkit.modal('#modal-overflow').show();
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
//    cache: false,
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


