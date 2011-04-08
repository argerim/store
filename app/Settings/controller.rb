require 'rho'
require 'rho/rhocontroller'
require 'rho/rhoerror'
require 'helpers/browser_helper'

class SettingsController < Rho::RhoController
  include BrowserHelper

  def index
    @msg = @params['msg']
    render
  end

  def send_log
    Rho::RhoConfig.send_log
    render :action => :index
  end
  
  def login
    @msg = @params['msg']
    render :action => :login, :back => '/app'
  end

  def wait_sync
    render
  end

  def login_callback
    errCode = @params['error_code'].to_i
    if errCode == 0
      # run sync if we were successful
      # WebView.navigate Rho::RhoConfig.options_path
      WebView.navigate (url_for :action => :wait_sync)
      SyncEngine.dosync
    else
      if errCode == Rho::RhoError::ERR_CUSTOMSYNCSERVER
        @msg = @params['error_message']
      end

      if !@msg || @msg.length == 0
        @msg = Rho::RhoError.new(errCode).message
      end

      WebView.navigate (url_for :action => :login, :query => {:msg => @msg})
    end
  end

  def do_login
    if @params['login'] and @params['password']
      begin
        SyncEngine.login(@params['login'], @params['password'], (url_for :action => :login_callback))
        render :action => :wait
      rescue Rho::RhoError => e
        @msg = e.message
        render :action => :login, :query => {:msg => @msg}
      end
    else
      @msg = Rho::RhoError.err_message(Rho::RhoError::ERR_UNATHORIZED) unless @msg && @msg.length > 0
      render :action => :login, :query => {:msg => @msg}
    end
  end

  def logout
    SyncEngine.logout
    @msg = "You have been logged out."
    render :action => :login
  end

  def reset
    render :action => :reset
  end

  def do_reset
    Rhom::Rhom.database_full_reset(false, false)
    SyncEngine.dosync
    @msg = "Database has been reset."
    redirect :action => :index, :query => {:msg => @msg}
  end

  def do_sync
    SyncEngine.dosync
    @msg =  "Sync has been triggered."
    redirect :action => :index, :query => {:msg => @msg}
  end

  def sync_object_notify
    puts 'sync_object_notify: ' + @params.inspect
    
    WebView.refresh
  end
    
  def sync_notify
  	puts 'sync_notify: ' + @params.inspect  
  	status = @params['status'] ? @params['status'] : ""
  	
  	Alert.show_status( "Status", "#{@params['source_name']} : #{status}", Rho::RhoMessages.get_message('hide'))
  	
  	if status == "in_progress" 	
  	    #do nothing
  	elsif status == "complete" #|| status == "ok"
        WebView.navigate Rho::RhoConfig.start_path if ( @params['sync_type'] != 'bulk') 
  	elsif status == "error"
  	
        if @params['server_errors'] && @params['server_errors']['create-error']
            SyncEngine.on_sync_create_error( @params['source_name'], @params['server_errors']['create-error'].keys(), :delete)
        end

        if @params['server_errors'] && @params['server_errors']['update-error']
            puts "on_sync_update_error START" 
            SyncEngine.on_sync_update_error( @params['source_name'], @params['server_errors']['update-error'], :retry)
            puts "on_sync_update_error END"
        end
        
        err_code = @params['error_code'].to_i
        rho_error = Rho::RhoError.new(err_code)
        
        @msg = @params['error_message'] if err_code == Rho::RhoError::ERR_CUSTOMSYNCSERVER
        @msg = rho_error.message() unless @msg && @msg.length > 0   

        if  rho_error.unknown_client?(@params['error_message'])
            Rhom::Rhom.database_client_reset
            SyncEngine.dosync
        elsif err_code == Rho::RhoError::ERR_UNATHORIZED
            WebView.navigate ( url_for :action => :login, :query => {:msg => "Server credentials are expired"} )                
        else
            WebView.navigate ( url_for :action => :err_sync, :query => {:msg => @msg} )
        end    
	end
  end
end
