-- Qorybook: penghitung pengguna anonim + perkenalan orang tua (opt-in).
-- Sudah diterapkan 2026-10-25 di proyek fiehwzkuqkslmyzexzgx (diuji lewat REST dengan
-- kunci publishable). Untuk proyek lain: jalankan di SQL Editor, lalu isi TELEMETRY_URL
-- dan TELEMETRY_KEY (publishable/anon key) saat build aplikasi.
--
-- Prinsip: kunci anon hanya boleh memanggil 4 fungsi di bawah. Tidak ada akses
-- baca/tulis langsung ke tabel, jadi data tidak bisa dibaca orang lain.

create table if not exists public.installs (
  install_id  text primary key,
  first_seen  timestamptz not null default now(),
  last_seen   timestamptz not null default now(),
  app_version text,
  platform    text,
  source      text
);

create table if not exists public.events (
  id         bigint generated always as identity primary key,
  install_id text not null,
  type       text not null,
  data       jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists events_type_time on public.events (type, created_at desc);

create table if not exists public.supporters (
  install_id text primary key,
  nickname   text not null,
  contact    text,
  consent    boolean not null default false,
  thanked    boolean not null default false,  -- tandai manual setelah kamu mengucapkan terima kasih
  created_at timestamptz not null default now()
);

alter table public.installs   enable row level security;
alter table public.events     enable row level security;
alter table public.supporters enable row level security;
-- Tanpa policy: anon dan authenticated tidak bisa menyentuh tabel langsung.

create or replace function public.ping(p_install_id text, p_version text, p_platform text, p_source text)
returns void language sql security definer set search_path = public as $$
  insert into installs (install_id, app_version, platform, source)
  values (left(p_install_id, 64), left(p_version, 20), left(p_platform, 20), left(p_source, 20))
  on conflict (install_id) do update
    set last_seen = now(), app_version = excluded.app_version;
$$;

create or replace function public.log_event(p_install_id text, p_type text, p_data jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_type not in ('donate_tap', 'donation_recorded') then
    raise exception 'event tidak dikenal';
  end if;
  insert into events (install_id, type, data)
  values (left(p_install_id, 64), p_type, coalesce(p_data, '{}'::jsonb));
end $$;

create or replace function public.register_supporter(p_install_id text, p_nickname text, p_contact text, p_consent boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not coalesce(p_consent, false) then
    raise exception 'butuh persetujuan';
  end if;
  insert into supporters (install_id, nickname, contact, consent)
  values (left(p_install_id, 64), left(p_nickname, 40), left(p_contact, 80), true)
  on conflict (install_id) do update
    set nickname = excluded.nickname, contact = excluded.contact, consent = true;
end $$;

create or replace function public.forget_supporter(p_install_id text)
returns void language sql security definer set search_path = public as $$
  delete from supporters where install_id = left(p_install_id, 64);
$$;

revoke all on function public.ping(text, text, text, text)                    from public;
revoke all on function public.log_event(text, text, jsonb)                    from public;
revoke all on function public.register_supporter(text, text, text, boolean)   from public;
revoke all on function public.forget_supporter(text)                          from public;
grant execute on function public.ping(text, text, text, text)                  to anon;
grant execute on function public.log_event(text, text, jsonb)                  to anon;
grant execute on function public.register_supporter(text, text, text, boolean) to anon;
grant execute on function public.forget_supporter(text)                        to anon;

-- Ringkasan untuk kamu (jalankan di SQL Editor):
-- select count(*) as pemasang, count(*) filter (where last_seen > now() - interval '7 days') as aktif_7_hari from installs;
-- select source, count(*) from installs group by source;
-- select type, count(*) from events group by type;
-- select s.nickname, s.contact, s.thanked, e.data->>'amount' as nominal, e.created_at
--   from supporters s left join events e on e.install_id = s.install_id and e.type = 'donation_recorded'
--   order by e.created_at desc;
