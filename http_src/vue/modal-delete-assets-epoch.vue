<!-- (C) 2022 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>
      {{ _i18n("asset_details.delete_asset_title") }}
    </template>
    <template v-slot:body>
      {{ _i18n("asset_details.delete_asset_older") }}
      <br>
      {{ _i18n("asset_details.last_time_seen") + ": " }}
      <div class="btn-group ms-2 mt-3 mb-3">
        <span class="input-group-text">
          <i class="fas fa-calendar-alt"></i>
        </span>
        <input class="flatpickr flatpickr-input form-control" type="text" placeholder="Choose a date.."
          data-id="datetime" ref="begin_date" style="width:10rem;">
      </div>
    </template><!-- modal-body -->
    <template v-slot:footer>
      <button type="button" @click="delete_host" class="btn btn-danger" :disabled="disable_delete">{{ _i18n("delete")
        }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as modal } from "./modal.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services";

const _i18n = (t) => i18n(t);
const format = ref('csv');
const selected_epoch = ref();
const return_message = ref('')
const show_return_msg = ref(false)
const err = ref(false);
const begin_date = ref();
const disable_delete = ref(true);

const emit = defineEmits(["delete_host"]);
const modal_id = ref();
const flat_begin_date = ref();

const props = defineProps({
  context: Object,
});

onMounted(() => {
  let f_set_picker = (picker, var_name) => {
    return flatpickr(begin_date.value, {
      enableTime: true,
      dateFormat: "d/m/Y H:i",
      time_24hr: true,
      clickOpens: true,
      onChange: function (selectedDates, dateStr, instance) {
        disable_delete.value = false;
      }
    });
  }
  flat_begin_date.value = f_set_picker("begin-date", "begin_date");
});


function server_date_to_date(date, format) {
  let utc = date.getTime();
  let local_offset = date.getTimezoneOffset();
  let server_offset = moment.tz(utc, ntop_zoneinfo)._offset;
  let offset_minutes = server_offset + local_offset;
  let offset_ms = offset_minutes * 1000 * 60;
  var d_local = new Date(utc - offset_ms);
  return d_local;
}

async function delete_host() {
  const url = `${http_prefix}/lua/rest/v2/delete/host/asset.lua`;
  const begin_date = server_date_to_date(flat_begin_date.value.selectedDates[0]);
  const epoch_begin = ntopng_utility.get_utc_seconds(begin_date.getTime());
  const params = {
    csrf: props.context.csrf,
    ifid: props.context.ifid,
    serial_key: epoch_begin,
  };

  const res = await ntopng_utility.http_post_request(url, params);
  if (res) {
    close();
  }
}

const show = () => {
  modal_id.value.show();
};

const close = () => {
  setTimeout(() => {
    modal_id.value.close();
    emit("delete");
  }, 500 /* .5 seconds */)
};

defineExpose({ show, close });

</script>
