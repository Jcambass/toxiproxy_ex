defmodule ToxiproxyExTest do
  use ExUnit.Case
  doctest ToxiproxyEx

  import ToxiproxyEx.TestHelpers
  import ToxiproxyEx.ProxyAssertions

  alias ToxiproxyEx.{Proxy, Toxic, ToxicCollection}

  setup do
    on_exit(fn ->
      Enum.map(ToxiproxyEx.all!().proxies, fn proxy ->
        :ok = ToxiproxyEx.Proxy.destroy(proxy)
      end)
    end)
  end

  test "create proxy" do
    proxy = ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master")

    assert "localhost:3306" == proxy.upstream
    assert "test_mysql_master" == proxy.name
  end

  test "create and find proxy" do
    proxy = ToxiproxyEx.create!(upstream: "localhost:3308", name: "test_redis_master")

    assert "localhost:3308" == proxy.upstream
    assert "test_redis_master" == proxy.name

    proxy = ToxiproxyEx.get!(:test_redis_master)

    assert "localhost:3308" == proxy.upstream
    assert "test_redis_master" == proxy.name
  end

  test "destroy proxy" do
    proxy = ToxiproxyEx.create!(upstream: "localhost:3308", name: "test_redis_master")
    assert :ok = ToxiproxyEx.destroy!(proxy)
    assert %ToxicCollection{proxies: []} = ToxiproxyEx.all!()
  end

  test "destroy multiple proxies" do
    ToxiproxyEx.create!(upstream: "localhost:3308", name: "test_redis_master")
    ToxiproxyEx.create!(upstream: "localhost:3309", name: "test_redis_follower")

    proxies = ToxiproxyEx.all!()
    assert :ok = ToxiproxyEx.destroy!(proxies)
    assert %ToxicCollection{proxies: []} = ToxiproxyEx.all!()
  end

  test "reset" do
    with_tcpserver(fn port ->
      proxy = ToxiproxyEx.create!(upstream: "localhost:#{port}", name: "test_echo_server")

      # Use private APIs to simulate changes to the toxiproxy instance that we want to reset.
      Proxy.disable(proxy)
      assert_proxy_unavailable(proxy)

      Toxic.new(type: :latency, attributes: %{latency: 123}, proxy_name: proxy.name)
      |> Toxic.create()

      ToxiproxyEx.reset!()

      assert_proxy_available(proxy)

      # Use private API to retrieve toxics for the proxy.
      {:ok, proxies} = Proxy.toxics(proxy)
      assert Enum.empty?(proxies)
    end)
  end

  test "take endpoint down" do
    with_tcpserver(fn port ->
      proxy = ToxiproxyEx.create!(upstream: "localhost:#{port}", name: "test_echo_server")

      ToxiproxyEx.down!(proxy, fn ->
        assert_proxy_unavailable(proxy)
      end)

      assert_proxy_available(proxy)
    end)
  end

  test "handles non existing proxies" do
    assert_raise ArgumentError, "Unknown proxy with name 'i_do_not_exist'", fn ->
      ToxiproxyEx.get!(:i_do_not_exist)
    end

    assert_raise ArgumentError, "Unknown proxy with name 'i_do_not_exist'", fn ->
      ToxiproxyEx.get!("i_do_not_exist")
    end
  end

  test "handles atom lookups" do
    with_tcpserver(fn port ->
      ToxiproxyEx.create!(upstream: "localhost:#{port}", name: "test_echo_server")
      ToxiproxyEx.get!("test_echo_server")
      ToxiproxyEx.get!(:test_echo_server)
    end)
  end

  test "returns all proxies" do
    with_tcpservers(2, fn [port1, port2] ->
      proxy1 = ToxiproxyEx.create!(upstream: "localhost:#{port1}", name: "test_echo_server_1")
      proxy2 = ToxiproxyEx.create!(upstream: "localhost:#{port2}", name: "test_echo_server_2")

      collection = ToxiproxyEx.all!()

      assert %ToxicCollection{} = collection

      names =
        collection.proxies
        |> Enum.map(& &1.name)
        |> Enum.sort()

      assert names == Enum.sort([proxy1.name, proxy2.name])
    end)
  end

  test "down on proxy collection disables entire collection" do
    with_tcpservers(2, fn [port1, port2] ->
      proxy1 = ToxiproxyEx.create!(upstream: "localhost:#{port1}", name: "test_echo_server_1")
      proxy2 = ToxiproxyEx.create!(upstream: "localhost:#{port2}", name: "test_echo_server_2")

      assert_proxy_available(proxy1)
      assert_proxy_available(proxy2)

      ToxiproxyEx.all!()
      |> ToxiproxyEx.down!(fn ->
        assert_proxy_unavailable(proxy1)
        assert_proxy_unavailable(proxy2)
      end)

      assert_proxy_available(proxy1)
      assert_proxy_available(proxy2)
    end)
  end

  test "grep returns toxic collection" do
    with_tcpservers(3, fn [port1, port2, port3] ->
      primary_psql_proxy =
        ToxiproxyEx.create!(upstream: "localhost:#{port1}", name: "test_primary_psql_server")

      primary_redis_proxy =
        ToxiproxyEx.create!(upstream: "localhost:#{port2}", name: "test_primary_redis_server")

      ToxiproxyEx.create!(upstream: "localhost:#{port3}", name: "test_secondary_psql_server")

      collection = ToxiproxyEx.grep!(~r/primary/)

      assert %ToxicCollection{} = collection

      names =
        collection.proxies
        |> Enum.map(& &1.name)
        |> Enum.sort()

      assert names == Enum.sort([primary_psql_proxy.name, primary_redis_proxy.name])
    end)
  end

  test "apply upstream toxic" do
    with_tcpserver(fn port ->
      proxy = ToxiproxyEx.create!(upstream: "localhost:#{port}", name: "test_echo_server")

      proxy
      |> ToxiproxyEx.upstream(:latency, latency: 100)
      |> ToxiproxyEx.apply!(fn ->
        {duration, data} =
          measure(fn ->
            write_to_proxy(proxy, "hello")
          end)

        assert "hello\n" = data

        assert_in_delta duration, 100, 20
      end)
    end)
  end

  test "apply downstream toxic" do
    with_tcpserver(fn port ->
      proxy = ToxiproxyEx.create!(upstream: "localhost:#{port}", name: "test_echo_server")

      proxy
      |> ToxiproxyEx.downstream(:latency, latency: 100)
      |> ToxiproxyEx.apply!(fn ->
        {duration, data} =
          measure(fn ->
            write_to_proxy(proxy, "hello")
          end)

        assert "hello\n" = data

        assert_in_delta duration, 100, 20
      end)
    end)
  end

  test "toxic default name is type and stream" do
    with_tcpserver(fn port ->
      proxy = ToxiproxyEx.create!(upstream: "localhost:#{port}", name: "test_echo_proxy")

      proxy
      |> ToxiproxyEx.downstream(:latency, latency: 100)
      |> ToxiproxyEx.upstream(:latency, latency: 100)
      |> ToxiproxyEx.upstream(:latency, latency: 100, name: "my_upstream_toxic")
      |> ToxiproxyEx.apply!(fn ->
        # Use private API to retrieve toxics for the proxy.
        {:ok, toxics} = Proxy.toxics(proxy)

        names = Enum.map(toxics, & &1.name) |> Enum.sort()
        assert names == Enum.sort(["latency_downstream", "latency_upstream", "my_upstream_toxic"])
      end)
    end)
  end

  test "populate created proxies array" do
    with_tcpservers(3, fn [port1, port2, port3] ->
      collection =
        ToxiproxyEx.populate!([
          %{
            name: "test_echo_proxy",
            upstream: "localhost:#{port1}",
            listen: "localhost:2333"
          },
          %{
            name: "test_redis_proxy",
            upstream: "localhost:#{port2}"
          },
          %{
            name: "test_pg_proxy",
            upstream: "localhost:#{port3}",
            listen: "localhost:2555",
            enabled: false
          }
        ])

      assert %ToxicCollection{} = collection

      all = ToxiproxyEx.all!()

      assert Enum.sort(all.proxies, &(&1.name > &2.name)) ==
               Enum.sort(collection.proxies, &(&1.name > &2.name))
    end)
  end

  test "populate creates proxies update listen" do
    with_tcpserver(fn port ->
      upstream = "localhost:#{port}"

      ToxiproxyEx.create!(upstream: upstream, listen: "localhost:8888", name: "test_echo_proxy")

      %ToxicCollection{proxies: proxies} =
        ToxiproxyEx.populate!([%{
          name: "test_echo_proxy",
          upstream: upstream,
          listen: "localhost:5555"
        }])

      assert Enum.count(proxies) == 1

      assert %Proxy{upstream: ^upstream, listen: "127.0.0.1:5555", name: "test_echo_proxy"} =
               hd(proxies)
    end)
  end

  test "populate creates proxies update upstream" do
    with_tcpservers(2, fn [port1, port2] ->
      ToxiproxyEx.create!(upstream: "localhost:#{port1}", name: "test_echo_proxy")

      new_upstream = "localhost:#{port2}"

      %ToxicCollection{proxies: proxies} =
        ToxiproxyEx.populate!([%{
          name: "test_echo_proxy",
          upstream: new_upstream
        }])

      assert Enum.count(proxies) == 1
      assert %Proxy{upstream: ^new_upstream, name: "test_echo_proxy"} = hd(proxies)
    end)
  end

  test "version" do
    version = ToxiproxyEx.version!()
    assert String.starts_with?(version, "2.")
  end

  test "multiple of same toxic type" do
    with_tcpserver(fn port ->
      proxy = ToxiproxyEx.create!(upstream: "localhost:#{port}", name: "test_echo_server")

      proxy
      |> ToxiproxyEx.downstream(:latency, latency: 100)
      |> ToxiproxyEx.downstream(:latency, latency: 100, name: "second_latency")
      |> ToxiproxyEx.apply!(fn ->
        {duration, data} =
          measure(fn ->
            write_to_proxy(proxy, "hello")
          end)

        assert "hello\n" = data

        assert_in_delta duration, 200, 20
      end)
    end)
  end

  test "multiple of same toxic type with same name" do
    with_tcpserver(fn port ->
      proxy = ToxiproxyEx.create!(upstream: "localhost:#{port}", name: "test_echo_server")

      collection =
        proxy
        |> ToxiproxyEx.downstream(:latency, latency: 100)
        |> ToxiproxyEx.downstream(:latency, latency: 100)

      assert_raise ArgumentError,
                   "There are multiple toxics with the name 'latency_downstream' for proxy 'test_echo_server', please override the default name (<type>_<direction>)",
                   fn ->
                     ToxiproxyEx.apply!(collection, fn ->
                       nil
                     end)
                   end
    end)
  end
end
