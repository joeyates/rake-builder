load File.dirname(__FILE__) + '/spec_helper.rb'

describe 'when creating tasks' do

  before( :each ) do
    Rake::Task.clear
  end

  after( :each ) do
    `rm -f spec/.rake-builder.foo`
  end

  it 'raises an error when the target is an empty string' do
    lambda do
      Rake::Builder.new do |builder|
        builder.target = ''
        builder.source_search_paths = [ 'cpp_project' ]
      end
    end.should raise_error(Rake::Builder::Error, 'The target name cannot be an empty string')
  end

  it 'raises an error when the target is set to nil' do
    lambda do
      Rake::Builder.new do |builder|
        builder.target = nil
        builder.source_search_paths = [ 'cpp_project' ]
      end
    end.should raise_error(Rake::Builder::Error, 'The target name cannot be nil')
  end

  it 'sets the target to \'a.out\' if it is not set' do
    here = File.dirname(File.expand_path(__FILE__))
    builder = Rake::Builder.new do |builder|
      builder.source_search_paths = ['projects/cpp_project']
    end

    expected = File.expand_path('a.out', here)
    expect(builder.target).to eq(expected)
  end

  it 'raises an error when the supplied target_type is unknown' do
    lambda do
      project = Rake::Builder.new do |builder|
        builder.target      = 'my_prog'
        builder.target_type = :foo
        builder.source_search_paths = [ 'cpp_project' ]
      end
    end.should raise_error
  end

end
