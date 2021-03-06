require 'spec_helper'

describe 'users/show.html.erb' do
  before :each do
    now = DateTime.now
    thirty_days_ago = (now - 33)
    @projects = [
        mock_model(Project, friendly_id: 'title-1', title: 'Title 1'),
        mock_model(Project, friendly_id: 'title-2', title: 'Title 2'),
        mock_model(Project, friendly_id: 'title-3', title: 'Title 3')
    ]
    @user = FactoryGirl.create(:user,
                              first_name: 'Eric',
                              last_name: 'Els',
                              email: 'eric@somemail.se',
                              title_list: 'Philanthropist',
                              created_at: thirty_days_ago,
                              github_profile_url: 'http://github.com/Eric',
                              skill_list: [ 'Shooting', 'Hooting' ],
                              bio: 'Lonesome Cowboy')

    @user.status.build(attributes = FactoryGirl.attributes_for(:status))

    @commit_counts = [build_stubbed(:commit_count, project: @projects.first, user: @user, commit_count: 253)]

    allow(@user).to receive(:following_projects).and_return(@projects)
    allow(@user).to receive(:following_projects_count).and_return(2)
    allow(@user).to receive(:commit_counts).and_return(@commit_counts)
    allow(@user).to receive(:following?).and_return(true)
    allow(@user).to receive(:status?).and_return(true)
    allow(@commit_counts.first.project).to receive(:contribution_url).and_return('test_url')

    assign :user, @user
    @youtube_videos = [
        {
            url: "http://www.youtube.com/100",
            title: "Random",
            published: '01/02/2015'.to_date
        },
        {
            url: "http://www.youtube.com/340",
            title: "Stuff",
            published: '01/03/2015'.to_date
        },
        {
            url: "http://www.youtube.com/2340",
            title: "Here's something",
            published: '01/04/2015'.to_date
        }
    ]
    assign :youtube_videos, @youtube_videos
    @skills = ["rails", "ruby", "rspec"]
    assign :skills, @skills
  end

  describe 'user information tabs' do
    it 'renders a tab view' do
      render
      expect(rendered).to have_css('ul#tabs')
    end

    it 'do not render tab About if user has no :bio' do
      allow(@user).to receive(:bio?).and_return false
      render
      rendered.within('ul#tabs') do |section|
        expect(section).to_not have_link 'About', href: '#about'
      end
    end

    it 'do not render tab Skills if user has no :skill_list' do
      allow(@user).to receive(:skill_list).and_return([])
      render
      rendered.within('ul#tabs') do |section|
        expect(section).to_not have_link 'Skills', href: '#user-skills'
      end
    end

    it 'do not render tab Projects if user has no :following_projects_count' do
      allow(@user).to receive(:following_projects_count).and_return 0
      render
      rendered.within('ul#tabs') do |section|
        expect(section).to_not have_link 'Projects', href: '#projects'
      end
    end

    it 'do not render tab Activity if user has no :commit_count' do
      allow(@user).to receive(:commit_counts).and_return []
      render
      rendered.within('ul#tabs') do |section|
        expect(section).to_not have_link 'Activity', href: '#activity'
      end
    end
  end

  it 'renders a table wih video links if there are videos' do
    render
    expect(render).to have_text('Title', 'Published')
  end

  it 'renders an embedded player' do
    expect(render).to have_selector('iframe#ytplayer')
  end

  it 'renders list of youtube links and published dates if user has videos' do
    render
    @youtube_videos.each do |video|
      expect(rendered).to have_link(video[:title], :href => video[:url])
      expect(rendered).to have_text(video[:published])
    end
  end

  it 'renders "no available videos" if user has no videos' do
    assign(:youtube_videos, nil)
    render
    expect(rendered).to have_text('Eric Els has no publicly viewable Youtube videos.')
  end

  it 'should render the users gravatar image' do
    render
    expect(rendered).to have_css('img[src*=gravatar]')
  end

  it 'renders user first and last names' do
    render
    expect(rendered).to have_content(@user.first_name)
    expect(rendered).to have_content(@user.last_name)
  end

  it 'renders user status' do
    render
    expect(rendered).to have_content(@user.status.last[:status])
  end

  it 'prompts user to update their status' do
    render
    expect(rendered).to have_selector('input', type: 'submit', value: 'Update status')
  end

  describe 'geolocation' do
    it 'does not show globe icon when no country is set' do
      render
      expect(rendered).not_to have_selector 'i[class="fa fa-globe fa-lg"]'
    end

    it 'shows user country when known' do
      @user.country = 'Mozambique'
      render
      expect(rendered).to have_selector 'i[class="fa fa-globe fa-lg"]'
      expect(rendered).to have_content @user.country
    end

    it 'does not show clock icon when user timezone cannot be determined' do
      render
      expect(rendered).not_to have_selector 'i[class="fa fa-clock-o fa-lg"]'
    end

    it 'shows user timezone when it can be determined' do
      @user.latitude = 25.9500
      @user.longitude = 32.5833
      expect(NearestTimeZone).to receive(:to).with(@user.latitude, @user.longitude).and_return('Africa/Cairo')
      render
      expect(rendered).to have_selector 'i[class="fa fa-clock-o fa-lg"]'
      expect(rendered).to have_content 'Africa/Cairo'
    end
  end

  it 'should not display an edit button if it is not my profile' do
    @user_logged_in ||= FactoryGirl.create :user
    sign_in @user_logged_in

    render
    expect(rendered).not_to have_link('Edit', href: '/users/edit')
  end

  context 'profile privacy' do

    it 'should display email if it is set to public' do
      @user.display_email = true
      render
      expect(rendered).to have_link(@user.email)
    end

    it 'should display an hire me button if it set to public' do
      @user.display_hire_me = true
      render
      expect(rendered).to have_link('Hire me', href: user_path(@user))
    end

    it 'should not display email if it is set to private' do
      @user.display_email = false
      render
      expect(rendered).to_not have_link(@user.email)
    end

    it 'should display an hire me button if it set to private' do
      @user.display_hire_me = false
      render
      expect(rendered).not_to have_link('Hire me', href: user_path(@user))
    end
  end

  it 'should display Member for ..' do
    render
    expect(rendered).to have_text('Member for about 1 month')
  end

  it 'should render the users bio' do
    render
    expect(rendered).to have_text('Lonesome Cowboy')
  end

  it 'should render the users title' do
    render
    expect(rendered).to have_text('Philanthropist')
  end

  it 'displays GitHub profile if it is linked' do
    render
    expect(rendered).to have_link('Eric', href: 'http://github.com/Eric')
  end

  context 'users own profile page' do
    before(:each) do
        @user_logged_in ||= FactoryGirl.create :user
        sign_in @user_logged_in # method from devise:TestHelpers
    end

    it 'does not display an edit button if it is not my profile' do
      render
      expect(rendered).to_not have_xpath("//a[contains(@type, 'button')]")
    end

    it 'displays an edit button if it is my profile' do
      assign(:user, @user_logged_in)
      render
      expect(rendered).to have_xpath("//a[contains(@type, 'button')]")
    end

    it 'does not display New Newsletter link if it is my profile and I am not privileged' do
      allow(@user).to receive(:is_privileged?).and_return(false)
      render
      expect(rendered).to_not have_link 'New Newsletter'
    end

    it 'does not display New Newsletter link if I am privileged and it is not my profile' do
      allow(@user).to receive(:is_privileged?).and_return(false)
      render
      expect(rendered).to_not have_link 'New Newsletter'
    end
  end

  context 'New Newsletter button' do
    before(:each) do
      @other = FactoryGirl.create(:user)
      @user = FactoryGirl.create(:user, email:'random@random.com')
      assign(:user, @user)
    end

    it 'displays New Newsletter link if it is my profile and I am privileged' do
      sign_in @user
      render
      expect(rendered).to have_link 'New Newsletter'
    end

    it 'does not display newsletter link if it not my profile even though user is privileged' do
      sign_in @other
      render
      expect(rendered).to_not have_link 'New Newsletter'
    end
  end

  it 'renders a list of contributions made by user' do
    render
    expect(rendered).to have_text('Title 1 - 253')
    expect(rendered).to have_link('Title', href: 'test_url')
  end

  it 'renders list of followed projects' do
    render
    @projects.each do |project|
      expect(rendered).to have_link(project.title, href: project_path(project))
    end
  end

  it 'renders list of user skills' do
    render
    @user.skill_list.each do |skill|
      expect(rendered).to have_text(skill)
    end
  end
end
