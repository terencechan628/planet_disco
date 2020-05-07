defmodule SpotifyTrackerWeb.Resolvers do
  import MonEx.{Result, Option}
  alias SpotifyTracker.{Repo, Artist, City}
  import Ecto.Query



  def get_artists(_, args, _) do
    sort = Map.get(args, :sort_by)
    q = Artist
    |> do_if(sort == "listeners" || sort == "score"  || Map.get(args, :by_city), fn query ->
      join(query, :left, [a], c in "artist_cities", as: :artist_city, on: c.artist_id == a.id)
    end)

    Enum.reduce(args, q, fn
      {:by_city, city_id}, q -> where(q, [_, artist_city: ac], ac.city_id == type(^city_id, :integer))
      _, q -> q
    end)
    |> do_if(Map.get(args, :min_listeners) != nil, fn query ->
      limit = Map.get(args, :min_listeners)
      where(query, [_, artist_city: ac], ac.listeners > type(^limit, :integer))
    end)
    |> sort_artists(sort)
    |> Repo.paginate(cursor(args))
    |> ok()
  end

  defp sort_artists(q, "listeners") do
    order_by(q, [_, artist_city: ac], [desc: ac.listeners, desc: :id])
  end

  defp sort_artists(q, "score") do
    order_by(q, [_, artist_city: ac], [desc: ac.score, desc: :id])
  end

  defp sort_artists(q, _) do
    order_by(q, [:name, :id])
  end

  def get_cities(_, args, _) do
    City
    |> sort_cities(args)
    |> Repo.paginate(cursor(args))
    |> ok()
  end

  defp sort_cities(q, %{q: term}) when not is_nil(term) or not term == "" do
    order_by(q, [p], desc: fragment("similarity(?, ?)", ^term, p.city), desc: :id)
  end

  defp sort_cities(q, _) do
    order_by(q, [:city, :id])
  end

  defp cursor(args) do
    Map.take(args, [:cursor, :limit])
    |> Map.put(:max_limit, 5000)
  end

  defp do_if(q, true, f), do: f.(q)
  defp do_if(q, false, f), do: q
end
