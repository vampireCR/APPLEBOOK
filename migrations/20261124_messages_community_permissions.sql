-- TheAppleBook: secure message actions, community management and avatar storage.
-- Idempotent; preserves existing rows.

-- 1) Message metadata and secure RPCs. RPCs are SECURITY DEFINER so they do not
-- depend on broad direct UPDATE/DELETE grants on the messages table.
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS edited_at timestamptz,
  ADD COLUMN IF NOT EXISTS reply_to_id uuid,
  ADD COLUMN IF NOT EXISTS pinned_at timestamptz,
  ADD COLUMN IF NOT EXISTS forwarded_from_id uuid;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='messages_reply_to_id_fkey' AND conrelid='public.messages'::regclass) THEN
    ALTER TABLE public.messages ADD CONSTRAINT messages_reply_to_id_fkey FOREIGN KEY (reply_to_id) REFERENCES public.messages(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='messages_forwarded_from_id_fkey' AND conrelid='public.messages'::regclass) THEN
    ALTER TABLE public.messages ADD CONSTRAINT messages_forwarded_from_id_fkey FOREIGN KEY (forwarded_from_id) REFERENCES public.messages(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.message_edit_own(target_message_id uuid, new_content text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF length(trim(coalesce(new_content,''))) NOT BETWEEN 1 AND 2000 THEN RAISE EXCEPTION 'Message must contain 1-2000 characters'; END IF;
  UPDATE public.messages AS m
    SET content = trim(new_content), edited_at = now()
    WHERE m.id = target_message_id AND m.sender_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Message not found or not yours'; END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.message_delete_own(target_message_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  DELETE FROM public.messages AS m WHERE m.id = target_message_id AND m.sender_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Message not found or not yours'; END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.message_toggle_pin(target_message_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE row_message public.messages%ROWTYPE; new_state boolean;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT * INTO row_message FROM public.messages m
   WHERE m.id = target_message_id AND (m.sender_id = auth.uid() OR m.receiver_id = auth.uid());
  IF NOT FOUND THEN RAISE EXCEPTION 'Message not found or access denied'; END IF;
  new_state := row_message.pinned_at IS NULL;
  UPDATE public.messages SET pinned_at = CASE WHEN new_state THEN now() ELSE NULL END WHERE id = target_message_id;
  RETURN new_state;
END; $$;

CREATE OR REPLACE FUNCTION public.message_forward(target_message_id uuid, target_receiver_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE source public.messages%ROWTYPE; new_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT * INTO source FROM public.messages m
   WHERE m.id = target_message_id AND (m.sender_id = auth.uid() OR m.receiver_id = auth.uid());
  IF NOT FOUND THEN RAISE EXCEPTION 'Source message not found or access denied'; END IF;
  IF target_receiver_id IS NULL OR target_receiver_id = auth.uid() THEN RAISE EXCEPTION 'Invalid destination'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = target_receiver_id) THEN RAISE EXCEPTION 'Recipient not found'; END IF;
  INSERT INTO public.messages(sender_id, receiver_id, content, forwarded_from_id)
  VALUES (auth.uid(), target_receiver_id, source.content, source.id)
  RETURNING id INTO new_id;
  RETURN new_id;
END; $$;

REVOKE ALL ON FUNCTION public.message_edit_own(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.message_delete_own(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.message_toggle_pin(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.message_forward(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.message_edit_own(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.message_delete_own(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.message_toggle_pin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.message_forward(uuid,uuid) TO authenticated;

-- 2) Compatibility for deployments where owner_id/created_by differed.
ALTER TABLE public.chat_groups ADD COLUMN IF NOT EXISTS owner_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.chat_groups ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.channels ADD COLUMN IF NOT EXISTS owner_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.channels ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.chat_groups ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.channels ADD COLUMN IF NOT EXISTS avatar_url text;

UPDATE public.chat_groups g SET owner_id = COALESCE(g.owner_id,g.created_by,m.user_id)
FROM public.chat_group_members m WHERE m.group_id=g.id AND m.member_role='owner' AND g.owner_id IS NULL;
UPDATE public.chat_groups SET created_by=owner_id WHERE created_by IS NULL AND owner_id IS NOT NULL;
UPDATE public.channels c SET owner_id = COALESCE(c.owner_id,c.created_by,m.user_id)
FROM public.channel_members m WHERE m.channel_id=c.id AND m.member_role='owner' AND c.owner_id IS NULL;
UPDATE public.channels SET created_by=owner_id WHERE created_by IS NULL AND owner_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.sync_community_owner_columns()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  NEW.owner_id := COALESCE(NEW.owner_id, NEW.created_by);
  NEW.created_by := COALESCE(NEW.created_by, NEW.owner_id);
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS chat_groups_sync_owner ON public.chat_groups;
CREATE TRIGGER chat_groups_sync_owner BEFORE INSERT OR UPDATE ON public.chat_groups FOR EACH ROW EXECUTE FUNCTION public.sync_community_owner_columns();
DROP TRIGGER IF EXISTS channels_sync_owner ON public.channels;
CREATE TRIGGER channels_sync_owner BEFORE INSERT OR UPDATE ON public.channels FOR EACH ROW EXECUTE FUNCTION public.sync_community_owner_columns();

-- Keep public channels discoverable by every signed-in user; private channels remain member-only.
DROP POLICY IF EXISTS channels_select_visible ON public.channels;
CREATE POLICY channels_select_visible ON public.channels FOR SELECT TO authenticated
USING (visibility='public' OR public.is_channel_member(id));
DROP POLICY IF EXISTS channel_posts_select_visible ON public.channel_posts;
CREATE POLICY channel_posts_select_visible ON public.channel_posts FOR SELECT TO authenticated
USING (public.is_channel_member(channel_id) OR EXISTS (SELECT 1 FROM public.channels c WHERE c.id=channel_id AND c.visibility='public'));

-- 3) Owner/admin management RPCs. The owner cannot be removed or demoted.
CREATE OR REPLACE FUNCTION public.community_update_group(target_group uuid, new_name text, new_description text, new_avatar_url text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.is_group_admin(target_group) THEN RAISE EXCEPTION 'Only group owners/admins can edit this group'; END IF;
  IF length(trim(coalesce(new_name,''))) NOT BETWEEN 2 AND 60 THEN RAISE EXCEPTION 'Group name must contain 2-60 characters'; END IF;
  UPDATE public.chat_groups SET name=trim(new_name), description=left(coalesce(new_description,''),500), avatar_url=nullif(trim(coalesce(new_avatar_url,'')),'') WHERE id=target_group;
END; $$;
CREATE OR REPLACE FUNCTION public.community_delete_group(target_group uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.chat_group_members m WHERE m.group_id=target_group AND m.user_id=auth.uid() AND m.member_role='owner') THEN RAISE EXCEPTION 'Only the group owner can delete this group'; END IF;
  DELETE FROM public.chat_groups WHERE id=target_group;
  IF NOT FOUND THEN RAISE EXCEPTION 'Group not found'; END IF;
END; $$;
CREATE OR REPLACE FUNCTION public.community_update_channel(target_channel uuid, new_name text, new_description text, new_avatar_url text, new_visibility text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.is_channel_admin(target_channel) THEN RAISE EXCEPTION 'Only channel owners/admins can edit this channel'; END IF;
  IF length(trim(coalesce(new_name,''))) NOT BETWEEN 2 AND 60 THEN RAISE EXCEPTION 'Channel name must contain 2-60 characters'; END IF;
  IF new_visibility NOT IN ('public','private') THEN RAISE EXCEPTION 'Invalid visibility'; END IF;
  UPDATE public.channels SET name=trim(new_name), description=left(coalesce(new_description,''),1000), avatar_url=nullif(trim(coalesce(new_avatar_url,'')),''), visibility=new_visibility WHERE id=target_channel;
END; $$;
CREATE OR REPLACE FUNCTION public.community_delete_channel(target_channel uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.channel_members m WHERE m.channel_id=target_channel AND m.user_id=auth.uid() AND m.member_role='owner') THEN RAISE EXCEPTION 'Only the channel owner can delete this channel'; END IF;
  DELETE FROM public.channels WHERE id=target_channel;
  IF NOT FOUND THEN RAISE EXCEPTION 'Channel not found'; END IF;
END; $$;

REVOKE ALL ON FUNCTION public.community_update_group(uuid,text,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.community_delete_group(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.community_update_channel(uuid,text,text,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.community_delete_channel(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.community_update_group(uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.community_delete_group(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.community_update_channel(uuid,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.community_delete_channel(uuid) TO authenticated;

-- 4) Public community-avatar bucket. Files are user-scoped on upload; public URLs are read-only.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES ('community-avatars','community-avatars',true,5242880,ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO UPDATE SET public=true, file_size_limit=5242880, allowed_mime_types=ARRAY['image/jpeg','image/png','image/webp'];
DROP POLICY IF EXISTS community_avatar_upload_own ON storage.objects;
CREATE POLICY community_avatar_upload_own ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id='community-avatars' AND (storage.foldername(name))[1]=auth.uid()::text);
DROP POLICY IF EXISTS community_avatar_update_own ON storage.objects;
CREATE POLICY community_avatar_update_own ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id='community-avatars' AND (storage.foldername(name))[1]=auth.uid()::text)
WITH CHECK (bucket_id='community-avatars' AND (storage.foldername(name))[1]=auth.uid()::text);
DROP POLICY IF EXISTS community_avatar_public_read ON storage.objects;
CREATE POLICY community_avatar_public_read ON storage.objects FOR SELECT TO public
USING (bucket_id='community-avatars');

NOTIFY pgrst, 'reload schema';

-- Pin messages/posts in group chats and channels as well.
ALTER TABLE public.chat_group_messages ADD COLUMN IF NOT EXISTS pinned_at timestamptz;
ALTER TABLE public.channel_posts ADD COLUMN IF NOT EXISTS pinned_at timestamptz;

CREATE OR REPLACE FUNCTION public.group_message_toggle_pin(target_message uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE g_id uuid; old_pin timestamptz; new_state boolean;
BEGIN
  SELECT group_id,pinned_at INTO g_id,old_pin FROM public.chat_group_messages WHERE id=target_message;
  IF NOT FOUND OR NOT public.is_group_admin(g_id) THEN RAISE EXCEPTION 'Only group admins can pin messages'; END IF;
  new_state := old_pin IS NULL;
  UPDATE public.chat_group_messages SET pinned_at=CASE WHEN new_state THEN now() ELSE NULL END WHERE id=target_message;
  RETURN new_state;
END; $$;

CREATE OR REPLACE FUNCTION public.channel_post_toggle_pin(target_post uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE c_id uuid; old_pin timestamptz; new_state boolean;
BEGIN
  SELECT channel_id,pinned_at INTO c_id,old_pin FROM public.channel_posts WHERE id=target_post;
  IF NOT FOUND OR NOT public.is_channel_admin(c_id) THEN RAISE EXCEPTION 'Only channel admins can pin publications'; END IF;
  new_state := old_pin IS NULL;
  UPDATE public.channel_posts SET pinned_at=CASE WHEN new_state THEN now() ELSE NULL END WHERE id=target_post;
  RETURN new_state;
END; $$;

CREATE OR REPLACE FUNCTION public.community_forward_to_dm(source_kind text, source_id uuid, target_receiver_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE message_text text; new_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF target_receiver_id IS NULL OR target_receiver_id=auth.uid() OR NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=target_receiver_id) THEN RAISE EXCEPTION 'Invalid recipient'; END IF;
  IF source_kind='group' THEN
    SELECT content INTO message_text FROM public.chat_group_messages WHERE id=source_id AND public.is_group_member(group_id);
  ELSIF source_kind='channel' THEN
    SELECT content INTO message_text FROM public.channel_posts WHERE id=source_id AND (public.is_channel_member(channel_id) OR EXISTS(SELECT 1 FROM public.channels c WHERE c.id=channel_id AND c.visibility='public'));
  ELSE RAISE EXCEPTION 'Unsupported source type'; END IF;
  IF message_text IS NULL THEN RAISE EXCEPTION 'Source content unavailable'; END IF;
  INSERT INTO public.messages(sender_id,receiver_id,content) VALUES(auth.uid(),target_receiver_id,message_text) RETURNING id INTO new_id;
  RETURN new_id;
END; $$;
REVOKE ALL ON FUNCTION public.group_message_toggle_pin(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.channel_post_toggle_pin(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.community_forward_to_dm(text,uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.group_message_toggle_pin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.channel_post_toggle_pin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.community_forward_to_dm(text,uuid,uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';

-- Ensure metadata columns exist on older installations too.
ALTER TABLE public.chat_groups ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '';
ALTER TABLE public.channels ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '';
ALTER TABLE public.chat_groups ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.channels ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
NOTIFY pgrst, 'reload schema';

-- Device tokens for native Android push notifications (FCM sender is configured separately).
CREATE TABLE IF NOT EXISTS public.push_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_token text NOT NULL UNIQUE,
  platform text NOT NULL DEFAULT 'android' CHECK (platform IN ('android','ios','web')),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.push_devices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS push_devices_select_own ON public.push_devices;
CREATE POLICY push_devices_select_own ON public.push_devices FOR SELECT TO authenticated USING (user_id=auth.uid());
DROP POLICY IF EXISTS push_devices_insert_own ON public.push_devices;
CREATE POLICY push_devices_insert_own ON public.push_devices FOR INSERT TO authenticated WITH CHECK (user_id=auth.uid());
DROP POLICY IF EXISTS push_devices_update_own ON public.push_devices;
CREATE POLICY push_devices_update_own ON public.push_devices FOR UPDATE TO authenticated USING (user_id=auth.uid()) WITH CHECK (user_id=auth.uid());
DROP POLICY IF EXISTS push_devices_delete_own ON public.push_devices;
CREATE POLICY push_devices_delete_own ON public.push_devices FOR DELETE TO authenticated USING (user_id=auth.uid());
GRANT SELECT,INSERT,UPDATE,DELETE ON public.push_devices TO authenticated;
NOTIFY pgrst, 'reload schema';

-- Include the actual birthday only when the profile owner explicitly made it visible.
CREATE OR REPLACE FUNCTION public.visible_profile_private(target_user uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT jsonb_build_object(
    'phone', CASE WHEN pp.phone_visible THEN pp.phone ELSE NULL END,
    'birth_date', CASE WHEN pp.birth_date_visible THEN pp.birth_date ELSE NULL END,
    'age', CASE WHEN pp.birth_date_visible AND pp.birth_date IS NOT NULL
      THEN extract(year FROM age(current_date, pp.birth_date))::integer ELSE NULL END
  )
  FROM public.profiles p
  LEFT JOIN public.profile_private pp ON pp.user_id=p.id
  WHERE p.id=target_user;
$$;
REVOKE ALL ON FUNCTION public.visible_profile_private(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.visible_profile_private(uuid) TO authenticated;
ALTER TABLE public.channel_posts ADD COLUMN IF NOT EXISTS views_count bigint NOT NULL DEFAULT 0;
NOTIFY pgrst, 'reload schema';
