<template>
    <div class="m-4 card card-shadow">
        <Loading :isLoading="isLoading"></Loading>
        <div class="card-body">
            <table class="table w-100 table-striped table-hover table-bordered">
                <tbody class="table_length">
                    <tr>
                        <td>
                            <div class="d-flex align-items-center">
                                <div class="col-4">
                                    <b>{{ _i18n('pcap_file') }}</b><br>
                                    <small>{{ _i18n('analyze_pcap_descr') }}</small>
                                </div>
                                <div class="col-8 form-group d-flex">
                                    <div class="">
                                        <input ref="pcap_file" class="form-control" type="file" name="pcap"
                                            accept=".pcap" @change="check_file" required>
                                    </div>
                                </div>
                            </div>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <div class="d-flex align-items-center">
                                <div class="col-4">
                                    <b>{{ _i18n('create_new_pcap_iface') }}</b><br>
                                    <small>{{ _i18n('create_new_pcap_iface_descr') }}</small>
                                </div>
                                <div class="col-8 form-group d-flex">
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox"
                                            @change="change_create_interface_option"
                                            :checked="!props.context.pcap_interface"
                                            :disabled="!props.context.pcap_interface">
                                    </div>
                                </div>
                            </div>
                        </td>
                    </tr>
                </tbody>
            </table>
            <div v-if="error.length > 0" class="text-danger">
                <span v-html="error"></span>
            </div>
            <div class="d-flex me-1">
                <button class="btn btn-primary" :disabled="disable_save" @click="upload_pcap">
                    {{ _i18n('upload_pcap') }}
                </button>
            </div>
        </div>
    </div>
    <ModalPcapUploaded ref="modal_pcap_uploaded" @load_interface="loadNewInterface">
    </ModalPcapUploaded>
</template>


<script setup>
import { ref, onMounted } from "vue";
import NtopUtils from "../utilities/ntop-utils.js";
import Loading from "./loading.vue";
import ModalPcapUploaded from "./modal-pcap-uploaded.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const pcap_file = ref(null)
const disable_save = ref(true)
const error = ref('')
const analyze_pcap_url = `${http_prefix}/lua/rest/v2/add/ntopng/analyze_pcap.lua`
const MAX_SIZE = 25 /* MB */ * 1024 * 1024;
const new_iface_id = ref(null);
const modal_pcap_uploaded = ref(null);
const isLoading = ref(true)
let create_new_interface = false

onMounted(() => {
    isLoading.value = false;
})

const check_file = function () {
    if (pcap_file.value?.files?.length > 0) {
        if (pcap_file.value.files[0].size > MAX_SIZE) {
            error.value = `${i18n('upload_pcap_max_size')}. File size: ${NtopUtils.bytesToSize(pcap_file.value.files[0].size)}`
            disable_save.value = true;
            pcap_file.value.classList.add('border')
            pcap_file.value.classList.add('border-danger')
        } else {
            error.value = ''
            disable_save.value = false;
            pcap_file.value.classList.remove('border')
            pcap_file.value.classList.remove('border-danger')
        }
    }
}

const upload_pcap = async function () {
    try {
        /* Check the file, if it's selected */
        if (!(pcap_file.value?.files?.length > 0)) {
            error.value = _i18n('please_select_a_file');
            return;
        }

        disable_save.value = true;
        error.value = '';
        isLoading.value = true;
        console.log(pcap_file)
        // Create a Form object to send the data.
        // The Files are no more sent correctly if not used a form
        // due to HTML5, hiding the file while sending normally over a connection
        const formData = new FormData();
        formData.append('pcap_file', pcap_file.value.files[0]);

        const response = await fetch(`${analyze_pcap_url}?create_new_interface=${(!props.context.pcap_interface) ? true : create_new_interface}`, {
            method: 'POST',
            body: formData,
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const result = await response.json();

        if (result.rc === 0) {
            if (modal_pcap_uploaded.value) {
                new_iface_id.value = result.rsp.new_ifid
                modal_pcap_uploaded.value.show()
            }
        } else {
            error.value = i18n("analyze_pcap_error")
        }
    } catch (e) {
        console.error('Upload error:', e);
        error.value = i18n("analyze_pcap_error")
    } finally {
        disable_save.value = true;
        isLoading.value = false;
    }
}

const change_create_interface_option = function () {
    create_new_interface = !create_new_interface
}

const loadNewInterface = function () {
    const form = document.createElement('form')
    form.method = 'post'
    form.action = `${http_prefix}/lua/flows_stats.lua?ifid=${new_iface_id.value}`

    const addField = (name, value) => {
        const input = document.createElement('input')
        input.type = 'hidden'
        input.name = name
        input.value = value
        form.appendChild(input)
    }

    addField('switch_interface', '1')
    addField('csrf', props.context.csrf)
    addField('ifid', new_iface_id.value)

    document.body.appendChild(form)
    form.submit()
}

</script>
