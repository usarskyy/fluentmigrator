require 'albacore'
require 'fileutils'

task :default => [:build]

msbuild :build do |msb|
  msb.path_to_command =  File.join(ENV['windir'], 'Microsoft.NET', 'Framework',  'v4.0.30319', 'MSBuild.exe')
  msb.properties :configuration => :Debug
  msb.targets :Clean, :Rebuild
  msb.solution = "FluentMigrator (2010).sln"
end

nunit :test => :build do |nunit|
  nunit.path_to_command = "tools/NUnit/nunit-console.exe"
  nunit.assemblies "src/FluentMigrator.Tests/bin/Debug/FluentMigrator.Tests.dll"
end

msbuild :release_compile do |msb|
  msb.path_to_command =  File.join(ENV['windir'], 'Microsoft.NET', 'Framework',  'v4.0.30319', 'MSBuild.exe')
  msb.properties :configuration => :Release
  msb.targets :Clean, :Rebuild
  msb.solution = "FluentMigrator (2010).sln"
end

exec :ilmerge_runner_with_providers do |cmd|
  FileUtils.mkdir_p 'il_merged'
  cmd.path_to_command = "tools/ILMerge.exe"
  cmd.parameters [
  	'/target:library',
  	'/out:il_merged\\FluentMigrator.Runner.dll',
  	'/zeroPeKind', # necessary for SQLLite, which isn't managed. might not work though...
  	'src\\FluentMigrator\\bin\\Release\\FluentMigrator.dll',
  	'src\\FluentMigrator.Runner\\bin\\Release\\FluentMigrator.Runner.dll',
  	'lib\\MySql.Data.dll',
  	'lib\\System.Data.SQLite.DLL'
  ]
end

exec :ilmerge_console_with_runner => :ilmerge_runner_with_providers do |cmd|
  cmd.path_to_command = "tools/ILMerge.exe"
  cmd.parameters [
  	'/target:winexe',
  	'/out:il_merged\\Migrate.exe',
  	'/zeroPeKind', # necessary for SQLLite, which isn't managed. might not work though...
  	'src\\FluentMigrator.Console\\bin\\x86\\Release\\Migrate.exe',
  	'il_merged\\FluentMigrator.Runner.dll'
  ]
end

exec :ilmerge_nant_with_runner => :ilmerge_runner_with_providers do |cmd|
  cmd.path_to_command = "tools/ILMerge.exe"
  cmd.parameters [
  	'/target:library',
  	'/out:il_merged\\FluentMigrator.NAnt.dll',
  	'/zeroPeKind', # necessary for SQLLite, which isn't managed. might not work though...
  	'src\\FluentMigrator.NAnt\\bin\\Release\\FluentMigrator.NAnt.dll',
  	'il_merged\\FluentMigrator.Runner.dll'
  ]
end

exec :ilmerge_msbuild_with_runner => :ilmerge_runner_with_providers do |cmd|
  cmd.path_to_command = "tools/ILMerge.exe"
  cmd.parameters [
  	'/target:library',
  	'/out:il_merged\\FluentMigrator.MSBuild.dll',
  	'/zeroPeKind', # necessary for SQLLite, which isn't managed. might not work though...
  	'src\\FluentMigrator.MSBuild\\bin\\Release\\FluentMigrator.MSBuild.dll',
  	'il_merged\\FluentMigrator.Runner.dll'
  ]
end

task :release => [:ilmerge_console_with_runner,:ilmerge_nant_with_runner,:ilmerge_msbuild_with_runner] do
end

def copy_files(from, to, filename, extensions)
	extensions.each do |ext|
		FileUtils.cp "#{from}#{filename}.#{ext}", "#{to}#{filename}.#{ext}"
	end
end

task :prepare_package => :release do
  output_directory_lib = './packages/FluentMigrator/lib/35/'
  output_directory_tools = './packages/FluentMigrator/tools/'
  FileUtils.mkdir_p output_directory_lib
  FileUtils.mkdir_p output_directory_tools

  copy_files './src/FluentMigrator/bin/Release/', output_directory_lib, 'FluentMigrator', ['dll', 'pdb', 'xml']
  copy_files './il_merged/', output_directory_tools, 'Migrate', ['exe']
  copy_files './src/FluentMigrator.Console/bin/x86/Release/', output_directory_tools, 'Migrate', ['exe.config']
  copy_files './il_merged/', output_directory_tools, 'FluentMigrator.NAnt', ['dll']
  copy_files './il_merged/', output_directory_tools, 'FluentMigrator.MSBuild', ['dll']

  FileUtils.remove_dir './il_merged/'
end

exec :package do |cmd|
  cmd.path_to_command = 'tools/NuPack.exe'
  cmd.parameters [
    'packages\\FluentMigrator\\FluentMigrator.nuspec',
    'packages\\FluentMigrator'
  ]
end