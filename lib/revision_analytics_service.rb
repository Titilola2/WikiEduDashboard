#= Queries for articles and revisions that have interesting properties
class RevisionAnalyticsService
  def self.dyk_eligible
    wp10_limit = ENV['dyk_wp10_limit'] || 30
    good_student_revisions = Revision
                             .where(user_id: current_student_ids)
                             .where('wp10 > ?', wp10_limit)
                             .where('date > ?', 2.months.ago)
    good_article_ids = good_student_revisions.pluck(:article_id)
    good_user_space = Article.where(id: good_article_ids)
                      .where(namespace: 2)
                      .where('title LIKE ?', '%/%') # only get subpages
                      .where('title NOT LIKE ?', '%/TWA/%') # skip TWA pages
                      .pluck(:id)
    good_draft_space = Article.where(id: good_article_ids)
                       .where(namespace: 118)
                       .pluck(:id)

    good_draft_ids = good_draft_space + good_user_space
    last_revisions = Revision
                     .where(article_id: good_draft_ids)
                     .select('MAX(date) as date, article_id')
                     .group(:article_id)
    last_rev_dates = {}
    last_revisions.each do |revision|
      last_rev_dates[revision.article_id] = revision.date
    end

    good_drafts = Article.where(id: good_draft_ids).to_a
    good_drafts.sort! { |a, b| last_rev_dates[a.id] <=>  last_rev_dates[b.id] }
    good_drafts.reverse!
    good_drafts
  end

  def self.suspected_plagiarism
    Revision.where.not(ithenticate_id: nil)
  end

  # Students in current courses, excluding instructors
  def self.current_student_ids
    current_course_ids = Course.current.pluck(:id)
    current_student_ids = CoursesUsers
                          .where(course_id: current_course_ids, role: 0)
                          .pluck(:user_id)
    current_instructor_ids = CoursesUsers
                             .where(course_id: current_course_ids, role: 1)
                             .pluck(:user_id)
    pure_student_ids = current_student_ids - current_instructor_ids
    pure_student_ids
  end
end
