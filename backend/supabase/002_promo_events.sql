-- Izinkan halaman promosi mencatat klik tombol unduh dan Saweria.
-- Jalankan di SQL Editor proyek Supabase setelah 001_telemetry.sql.
-- Hanya mengubah daftar event yang diterima log_event; tidak ada data pribadi.

create or replace function public.log_event(p_install_id text, p_type text, p_data jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_type not in ('donate_tap', 'donation_recorded', 'promo_download', 'promo_saweria') then
    raise exception 'event tidak dikenal';
  end if;
  insert into events (install_id, type, data)
  values (left(p_install_id, 64), p_type, coalesce(p_data, '{}'::jsonb));
end $$;

-- Pemantauan unduhan (jalankan kapan saja):
-- select date(created_at at time zone 'Asia/Jakarta') as hari,
--        count(*) as klik_unduh, count(distinct install_id) as pengunjung_unik
--   from events where type = 'promo_download' group by 1 order by 1 desc;
-- select count(*) filter (where type = 'promo_download') as klik_unduh,
--        count(*) filter (where type = 'promo_saweria')  as klik_saweria
--   from events;
-- select count(*) as pemasang_aktif_7_hari from installs where last_seen > now() - interval '7 days';
