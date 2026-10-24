-- Halaman pantau (/pantau): ringkasan pemasang, klik unduh, donasi, dan pendukung.
-- Jalankan sekali di SQL Editor setelah 001 dan 002. Aman dijalankan ulang.
--
-- Data hanya keluar lewat kode akses rahasia. Yang tersimpan di sini hanya hash-nya;
-- kodenya sendiri ada di tangan pemilik. Untuk mengganti kode: ubah hash di bawah
-- (sha256 dari kode, huruf kecil heksadesimal) lalu jalankan ulang bagian "kode akses".

-- ---------- 0. bersihkan data uji ----------
delete from public.events     where install_id in ('uji-claude-1792863784', 'web-uji-claude', 'web-657d096f62a30f33');
delete from public.supporters where install_id in ('uji-claude-1792863784', 'web-uji-claude', 'web-657d096f62a30f33');
delete from public.installs   where install_id in ('uji-claude-1792863784', 'web-uji-claude', 'web-657d096f62a30f33');

-- ---------- 1. kode akses ----------
create table if not exists public.admin_secret (
  id        int primary key default 1 check (id = 1),
  code_hash text not null
);
alter table public.admin_secret enable row level security;  -- tanpa policy: tidak terbaca anon

insert into public.admin_secret (id, code_hash) values (1, '419a7401695bb325aa1edcc3f5aa07cf831c6f10d1d4eb7f04996ff72e0efc8b')
on conflict (id) do update set code_hash = excluded.code_hash;

create or replace function public._pantau_cek(p_kode text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_kode is null
     or not exists (
       select 1 from admin_secret
       where code_hash = encode(sha256(convert_to(p_kode, 'utf8')), 'hex')
     )
  then
    perform pg_sleep(1);  -- memperlambat tebakan
    raise exception 'kode salah';
  end if;
end $$;

-- ---------- 2. ringkasan ----------
create or replace function public.pantau_ringkasan(p_kode text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  hasil jsonb;
begin
  perform _pantau_cek(p_kode);

  with hari as (
    select d::date as tgl from generate_series(
      (now() at time zone 'Asia/Jakarta')::date - 29, (now() at time zone 'Asia/Jakarta')::date, interval '1 day') d
  ),
  pemasang_harian as (
    select h.tgl, count(i.install_id) as n
    from hari h left join installs i on (i.first_seen at time zone 'Asia/Jakarta')::date = h.tgl
    group by h.tgl
  ),
  unduh_harian as (
    select h.tgl, count(e.id) as klik, count(distinct e.install_id) as unik
    from hari h left join events e
      on e.type = 'promo_download' and (e.created_at at time zone 'Asia/Jakarta')::date = h.tgl
    group by h.tgl
  ),
  donasi as (
    select install_id, sum((data->>'amount')::bigint) filter (where data ? 'amount') as total, count(*) as kali,
           max(created_at) as terakhir
    from events where type = 'donation_recorded' group by install_id
  )
  select jsonb_build_object(
    'dibuat', now(),
    'pemasang', (select count(*) from installs),
    'aktif_hari_ini', (select count(*) from installs where last_seen > now() - interval '1 day'),
    'aktif_7_hari', (select count(*) from installs where last_seen > now() - interval '7 days'),
    'pemasang_harian', (select jsonb_agg(jsonb_build_object('tgl', tgl, 'n', n) order by tgl) from pemasang_harian),
    'per_sumber', (select coalesce(jsonb_agg(jsonb_build_object('nama', nama, 'n', n) order by n desc), '[]'::jsonb)
                   from (select coalesce(source, '?') as nama, count(*) as n from installs group by 1) s),
    'per_platform', (select coalesce(jsonb_agg(jsonb_build_object('nama', nama, 'n', n) order by n desc), '[]'::jsonb)
                     from (select coalesce(platform, '?') as nama, count(*) as n from installs group by 1) s),
    'per_versi', (select coalesce(jsonb_agg(jsonb_build_object('nama', nama, 'n', n) order by n desc), '[]'::jsonb)
                  from (select coalesce(app_version, '?') as nama, count(*) as n from installs group by 1) s),
    'unduh_harian', (select jsonb_agg(jsonb_build_object('tgl', tgl, 'klik', klik, 'unik', unik) order by tgl) from unduh_harian),
    'unduh_klik', (select count(*) from events where type = 'promo_download'),
    'unduh_unik', (select count(distinct install_id) from events where type = 'promo_download'),
    'saweria_promo', (select count(*) from events where type = 'promo_saweria'),
    'saweria_aplikasi', (select count(*) from events where type = 'donate_tap'),
    'donasi_dicatat', (select count(*) from events where type = 'donation_recorded'),
    'donasi_total', (select coalesce(sum((data->>'amount')::bigint), 0) from events where type = 'donation_recorded' and data ? 'amount'),
    'pendukung', (select coalesce(jsonb_agg(jsonb_build_object(
        'install_id', s.install_id, 'nama', s.nickname, 'kontak', s.contact, 'sudah_diucapkan', s.thanked,
        'daftar', s.created_at, 'donasi_kali', coalesce(d.kali, 0), 'donasi_total', coalesce(d.total, 0),
        'donasi_terakhir', d.terakhir) order by s.thanked, s.created_at desc), '[]'::jsonb)
      from supporters s left join donasi d using (install_id))
  ) into hasil;

  return hasil;
end $$;

-- ---------- 3. tandai sudah diberi ucapan terima kasih ----------
create or replace function public.pantau_tandai(p_kode text, p_install_id text, p_sudah boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform _pantau_cek(p_kode);
  update supporters set thanked = coalesce(p_sudah, false) where install_id = left(p_install_id, 64);
end $$;

-- ---------- 4. izin ----------
revoke all on function public._pantau_cek(text)                 from public, anon;
revoke all on function public.pantau_ringkasan(text)            from public;
revoke all on function public.pantau_tandai(text, text, boolean) from public;
grant execute on function public.pantau_ringkasan(text)             to anon;
grant execute on function public.pantau_tandai(text, text, boolean) to anon;
