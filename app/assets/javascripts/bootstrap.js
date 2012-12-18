$(document).ready(function() {
   $('#id_search_btn').live('click', function(){
        $.ajax({
            cache: false,
            type: 'GET',
            url: '/home/process_tweets',
            data: {
                twitter_handle: $('#twitterHandle').val()
            },
            beforeSend: function(){
                $('#search_results').html("");
                $('#loader').show();
            },
            complete: function(){
                $('#loader').hide();
            }
        });
    });
});