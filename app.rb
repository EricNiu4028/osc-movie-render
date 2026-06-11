# frozen_string_literal: true

require 'sinatra/base'
require 'logger'
require 'json'

# App is the main application where all your logic & routing will go
class App < Sinatra::Base
  set :erb, escape_html: true
  enable :sessions
  set :host_authorization, { permitted_hosts: ['ondemand.osc.edu'] }

  attr_reader :logger

  def initialize
    super
    @logger = Logger.new('log/app.log')
  end

  def title
    'Summer Instititue Starter App'
  end

  get '/examples' do
    erb(:examples)
  end

  def project_root
    "#{__dir__}/projects"
  end

  def log_root
    "#{__dir__}/jobs"
  end

  def blend_files(project_name)
    Dir.glob("*.blend", base: "#{project_root}/#{project_name}/render/assets").select {|entry| !entry.start_with?('.') }
  end

  def project_files(project_name)
    file_hash = []
    Dir.glob("*", base: "#{project_root}/#{project_name}/render/assets").each do |file|
      is_file = File.file?("#{project_root}/#{project_name}/render/assets/#{file}")
      modification_time = File.mtime("#{project_root}/#{project_name}/render/assets/#{file}")
      uid = File.stat("#{project_root}/#{project_name}/render/assets/#{file}").uid
      file_hash.append({
        :name => file,
        :file => is_file,
        :full_path => "projects/#{project_name}/render/assets/#{file}",
        :mt_time => modification_time,
        :account => owner_name = Etc.getpwuid(uid).name
      })
    end
    file_hash
  end

  def accounts
    Process.groups.map do |group_id|
      Etc.getgrgid(group_id).name
    end.select do |group|
      group.start_with?('P')
    end
  end

  def project_dirs
    directory = Dir.new("projects")

    directory.children.select do |dir|
      Pathname.new("projects/#{dir}").directory?
    end.sort_by(&:to_s)
  end

  def frames(project_name)
    frame_dirs = []
    Dir.glob("*.png", base: "#{project_root}/#{project_name}/render/frames").each do |entry|
      !entry.start_with?('.')
      logger.info("#{project_root}/#{project_name}/render/frames/#{entry}")
      frame_dirs.append("#{project_root}/#{project_name}/render/frames/#{entry}")
    end

    if frame_dirs.empty?
      frame_dirs = ["#{__dir__}/docs/y9DpT.jpg"]
    end
    frame_dirs
  end

  post '/get/frames' do
    project_name = request.env['PROJECT_NAME']
    frames(project_name)
  end

  def videos(project_name)
    video_files = []
    Dir.glob("*.mp4", base: "#{project_root}/#{project_name}/render/video").each do |entry|
      !entry.start_with?('.')
      logger.info("#{project_root}/#{project_name}/render/video/#{entry}")
      video_files.append("#{project_root}/#{project_name}/render/video/#{entry}")
    end
    video_files
  end

  def jobs
    jobs_list = []
    (`sacctmgr list cluster -P -n format=Cluster`).split("\n").each do |cluster|
      args = ['--me', '-M', cluster, '--json', '-h']
      (JSON.parse(`/bin/squeue #{args.join(' ')}`, symbolize_names: true)[:jobs]).each do |job_inst|
        if job_inst[:name].include?('blender')
          jobs_list.append(job_inst)
        end
      end
    end
    jobs_list
  end

  def convert_datetime(time)
    Time.at(time).strftime("%b %d, %Y %H:%M %p")
  end

  get '/jobs/:id' do
    erb(:view_job)
  end

  post '/jobs/:id' do
    args = ["-M", "all", "--me", params[:job_id]]
    output = `/bin/scancel #{args.join(' ')}`
    redirect to("/")
  end

  get '/projects/:name' do
    @path = Pathname.new("projects/#{params[:name]}")

    if @path.directory? && @path.readable?
      erb(:view_project)
    elsif params[:name] == "new"
      erb(:new_project)
    else
      @flash = { error: "The project #{params[:name]} does not exist" }
      logger.info("Attempted to look for project: #{params[:name]}, but it didn't exist")
      redirect to("/projects/new")
    end
  end

  post '/projects/:name' do
    if params.key?(:delete)
      path = Pathname.new("projects/#{params[:delete]}")
      serialized = params[:name].downcase.gsub(" ", "_")

      logger.info("Deleting project #{params[:name]}")
      if path.directory? && path.readable?
        "#{__dir__}/projects/#{serialized}".tap { |dir| FileUtils.rm_r(dir)}
        redirect to("/")
      end
    else
      serialized = params[:project_name].downcase.gsub(" ", "_")

      if File.directory?("projects/#{serialized}")
        @flash = { error: "Project #{serialized} already exists" }
        erb(:new_project)
      else
        logger.info("Creating a new project with the name: #{params[:project_name]}")
        @flash = { success: "Creating a new project with the name: #{params[:project_name]}" }
        "#{__dir__}/projects/#{serialized}".tap { |dir| FileUtils.mkdir(dir) }
        FileUtils.mkdir_p("#{project_root}/#{serialized}/render/assets")
        FileUtils.mkdir_p("#{project_root}/#{serialized}/render/frames")
        FileUtils.mkdir_p("#{project_root}/#{serialized}/render/video")
        redirect to("/projects/#{serialized}")
      end
    end
  end

  post '/upload/file' do
    if params[:upload_file] && params[:upload_file][:filename]
      filename = params[:upload_file][:filename]
      tempfile = params[:upload_file][:tempfile]
      
      file_path = "#{project_root}/#{params[:project_name]}/render/assets"
      FileUtils.mkdir_p(file_path)

      File.open("#{file_path}/#{params[:upload_file][:filename]}", 'wb') do |f|
        f.write(tempfile.read)
      end
    end

    redirect to("/projects/#{params[:project_name]}")
  end

  get '/' do
    logger.info('requsting the index')
    @flash = session[:flash]
    @flash = { info: 'Beginning Bitcoin Mining Background Task...' }
    erb(:index)
  end

  post '/render/frames' do
    logger.info("A new render job has been created with the parameters: #{params}")
    job_id = ""

    if params[:nodes] == 1
      logger.info("The job was simple")
      args = ['-J', "blender-#{params[:project_name]}-#{params[:blend_file]}", '-A', params[:account], '-t', format('%02d:00:00', params[:walltime]), '-n', params[:num_cpus], '--parsable', '--export', "BLEND_FILE_PATH=#{project_root}/#{params[:project_name]}/render/assets/#{params[:blend_file]},START_FRAME=#{params[:frame_range].split('..').first},END_FRAME=#{params[:frame_range].split('..').last},OUTPUT_DIR=#{params[:project_directory]}/render/frames", '-N', '1', '-M', 'cardinal', "--ntasks=#{params[:num_tasks]}", '--output', "#{__dir__}/jobs/%j.out"]
      output = `/bin/sbatch #{args.join(' ')} #{__dir__}/scripts/render_frames.sh 2>&1`
      job_id = output.strip.split(';').first
    else
      logger.info("The job was complex")
      args = ['-J', "blender-#{params[:project_name]}-#{params[:blend_file]}", '-A', params[:account], '-t', format('%02d:00:00', params[:walltime]), '-n', '4', '--parsable', '--export', "BLENDER_PATH=#{__dir__},BLEND_FILE_PATH=#{project_root}/#{params[:project_name]}/render/assets/#{params[:blend_file]},START_FRAME=#{params[:frame_range].split('..').first},END_FRAME=#{params[:frame_range].split('..').last},OUTPUT_DIR=#{params[:project_directory]}/render/frames,TOTAL_NODES=#{params[:nodes]},PER_CPU=#{params[:num_cpus]}", '-N', '1', '-M', 'cardinal', "--ntasks=#{params[:num_tasks]}", '--output', "#{__dir__}/jobs/%j.out"]
      output = `/bin/sbatch #{args.join(' ')} #{__dir__}/scripts/render_batch.sh 2>&1`
      job_id = output.strip.split(';').first

      logger.info("/bin/sbatch #{args.join(' ')} #{__dir__}/scripts/render_batch.sh 2>&1")
    end
    @flash = { success: "Started rendering job #{job_id}" }
    redirect to("/projects/#{params[:project_directory].split('/').last}")
  end

  post '/render/video' do
    logger.info("A new video rendering job has been created with the parameters #{params}")
    logger.info("#{params[:project_directory]}/render/frames")

    args = ['-J', "blender-video-#{params[:project_name]}", '--parsable', '-A', params[:account], '--export', "OUTPUT_DIR=#{params[:project_directory]}/render/video,FRAMES_PER_SEC=#{params[:fps]},INPUT_DIR=#{params[:project_directory]}/render/frames", '-n', params[:num_cpus], '-t', format('%02d:00:00', params[:walltime]), '-M', 'pitzer', "--ntasks=#{params[:num_tasks]}", '--output', "#{__dir__}/jobs/%j.out"]
    output = `/bin/sbatch #{args.join(' ')}  #{__dir__}/scripts/render_video.sh 2>&1`
    logger.info(`/bin/sbatch #{args.join(' ')}  #{__dir__}/scripts/render_video.sh 2>&1`)
    job_id = output.strip.split(';').first

    @flash = { success: "Started rendering job #{job_id}" }
    redirect to("/projects/#{params[:project_directory].split('/').last}")
  end
end