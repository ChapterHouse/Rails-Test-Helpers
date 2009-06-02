require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

module Rake
  class RDocTaskSvn < RDocTask
    def define
      if name.to_s != "rdoc"
        desc "Build the RDOC HTML Files"
      end

      desc "Build the #{name} HTML Files"
      task name
      
      desc "Force a rebuild of the RDOC files"
      task paste("re", name) => [paste("clobber_", name), name]
      
      desc "Remove rdoc products" 
      task paste("clobber_", name) do
#        rm_f Dir.glob(File.join(@rdoc_dir, "**/*")).reject { |x| x == File.join(@rdoc_dir, "created.rid") } rescue nil
        rm_f Dir.glob(File.join(@rdoc_dir, "**/*")) rescue nil
        File.open(File.join(@rdoc_dir, "created.rid"), "w") { |file| file.puts 'Mon, 19 May 2007 20:05:58 -0500' }
#        rm_r rdoc_dir rescue nil
      end

      task :clobber => [paste("clobber_", name)]
      
      directory @rdoc_dir
      task name => [rdoc_target]
      file rdoc_target => @rdoc_files + [$rakefile || "Rakefile"] do
#        rm_f Dir.glob(File.join(@rdoc_dir, "**/*")).reject { |x| x == File.join(@rdoc_dir, "created.rid") } rescue nil
        rm_f Dir.glob(File.join(@rdoc_dir, "**/*")) rescue nil
        File.open(File.join(@rdoc_dir, "created.rid"), "w") { |file| file.puts 'Mon, 19 May 2007 20:05:58 -0500' }
#        rm_r @rdoc_dir rescue nil
        args = option_list + @rdoc_files
        if @external
          argstring = args.join(' ')
          sh %{ruby -Ivendor vender/rd #{argstring}}
        else
          require 'rdoc/rdoc'
          RDoc::RDoc.new.document(args)
        end
      end
      self
    end
  end
end


desc 'Default: run unit tests.'
task :default => :test

desc 'Test the rails_test_helpers plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the rails_test_helpers plugin.'
Rake::RDocTaskSvn.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'RailsTestHelpers'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
