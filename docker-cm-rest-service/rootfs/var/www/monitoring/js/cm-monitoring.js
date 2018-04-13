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
    trHTML += ' <a href="#" class="uk-icon-link add-annotation-for-host" uk-icon="commenting" uk-tooltip="add annotation"></a>';
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

  $('#monitoring-hosts').on('click', '.add-annotation-for-host', function(e) {
    e.preventDefault();
    e.target.blur();

    var $dialog = $('#modal-overflow');
    var $t = $(this)
    var $b = $t.closest('tr');
    var $hostname = $b.data('hostname');

//     console.debug($t);
//     console.debug($hostname);

    var dialogHTML = '';

    dialogHTML += '<div class="uk-modal-dialog">';
    dialogHTML += '  <button class="uk-modal-close-default" type="button" uk-close></button>';
    dialogHTML += '  <div class="uk-modal-header"><h2 class="uk-modal-title">Add Annotation for Host ' + $hostname + '</h2></div>';
    dialogHTML += '  <div class="uk-modal-body" uk-overflow-auto>';

    dialogHTML += '    <ul class="uk-tab" data-uk-tab="{connect:\'#my-id\'}">';
    dialogHTML += '      <li><a href="">Tab 1</a></li>';
    dialogHTML += '      <li><a href="">Tab 2</a></li>';
    dialogHTML += '      <li><a href="">Tab 3</a></li>';
    dialogHTML += '    </ul>';
    dialogHTML += '    <ul id="my-id" class="uk-switcher uk-margin">';
    dialogHTML += '      <li><a href="#" id="autoplayer" data-uk-switcher-item="next"></a>';
    dialogHTML += '       This slide contains a hidden link, that selects the next slide when clicked. The click is simulated by jacascript to mimic autoplay.';
    dialogHTML += '        </li>';
    dialogHTML += '      <li>Content 2';
    dialogHTML += '        <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p>';
    dialogHTML += '      </li>';
    dialogHTML += '      <li>Content 3</li>';
    dialogHTML += '    </ul>';

    dialogHTML += '    <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p>';
    dialogHTML += '  </div>';
    dialogHTML += '  <div class="uk-modal-footer uk-text-right">';
    dialogHTML += '    <button class="uk-button uk-button-default uk-modal-close" type="button">Cancel</button>';
    dialogHTML += '    <button id="add-annotation" class="uk-button uk-button-primary" type="button">Save</button>';
    dialogHTML += '  </div>';
    dialogHTML += '</div>';

    $dialog.html(dialogHTML);

    UIkit.modal($dialog).show();

    $dialog.on('click', '#add-annotation', function(e) {

      console.debug($hostname);
    });
  });

  $('#monitoring-hosts').on('click', '.delete-host', function() {

    var $dialog = $('#modal-overflow');
    var $t = $(this)
    var $b = $t.closest('tr');
    var $hostname = $b.data('hostname');

//     console.debug($t);
//     console.debug($hostname);

    var dialogHTML = '';

    dialogHTML += '<div class="uk-modal-dialog">';
    dialogHTML += '  <button class="uk-modal-close-default" type="button" uk-close></button>';
    dialogHTML += '  <div class="uk-modal-header"><h2 class="uk-modal-title">delete Host ' + $hostname + ' from monitoring</h2></div>';
    dialogHTML += '  <div class="uk-modal-body" uk-overflow-auto>';
    dialogHTML += '    <p>schould delete this host from monitoring?</p>';
    dialogHTML += '  </div>';
    dialogHTML += '  <div class="uk-modal-footer uk-text-right">';
    dialogHTML += '    <button class="uk-button uk-button-default uk-modal-close" type="button">Cancel</button>';
    dialogHTML += '    <button id="delete" class="uk-button uk-button-primary" type="button">Delete</button>';
    dialogHTML += '  </div>';
    dialogHTML += '</div>';

    $dialog.html(dialogHTML);

    UIkit.modal.confirm('<b>Delete</b> Host ' + $hostname + ' from monitoring', {
      labels: {
        cancel: 'Cancel',
        ok: 'DELETE this host from monitoring'
      }
    }).then(function () {
      console.log('Confirmed.')
    }, function () {
      console.log('Rejected.')
    });
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


