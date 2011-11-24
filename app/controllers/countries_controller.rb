class CountriesController < ApplicationController
  def index
    @countries = Country.all
  end

  def show
    @country = Country.find(params[:id])
    @news_articles = NewsArticle.published.in_country(@country).by_publication_date
    @policies = Policy.published.in_country(@country).by_publication_date
    @speeches = Speech.published.in_country(@country).by_publication_date
  end
end