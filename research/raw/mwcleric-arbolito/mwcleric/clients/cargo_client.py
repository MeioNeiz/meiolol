from typing import Union, List, Optional
import time

from mwcleric.clients.site import Site
from mwcleric.auth_credentials import AuthCredentials
from mwcleric.clients.session_manager import session_manager
from mwcleric.errors import RetriedLoginAndStillFailed
from mwclient.errors import APIError


class CargoClient(object):
    """
    Extends mwclient.Site with basic Cargo operations.
    """
    client = None

    def __init__(self, client: Site, credentials: AuthCredentials, max_retries: int, retry_interval: int, **kwargs):
        self.client = client
        self.credentials = credentials
        self.max_retries = max_retries
        self.retry_interval = retry_interval

    def _make_cargoquery_api_call(self, data, error_codes=[], retry_count=0):
        try:
            return self.client.api('cargoquery', **data)
        except APIError as e:
            if e.code not in ['ratelimited', 'permissiondenied'] or self.max_retries == 0:
                raise e
            # don't retry if permission is denied and we are logged out
            if e.code == 'permissiondenied' and self.credentials is None:
                raise e
            
            if retry_count >= self.max_retries:
                raise RetriedLoginAndStillFailed("cargoquery", error_codes)

            error_codes.append(e.code)
            session_manager.relog(self.client, self.credentials)
            
            # don't sleep at all the first retry, and then increment in retry_interval intervals
            # default interval is 10, default retries is 3
            time.sleep((2 ** retry_count - 1) * self.retry_interval)

            # only retry once if error is permissiondenied
            if e.code == "permissiondenied":
                retry_count = self.max_retries

            return self._make_cargoquery_api_call(data, error_codes, retry_count+1)

    def query(self, *, tables: Union[str, List[str]], fields: Union[str, List[str]],
              where: Optional[str] = None, join_on: Optional[Union[str, List[str]]] = None,
              group_by: Optional[str] = None, having: Optional[Union[str, List[str]]] = None,
              order_by: Optional[str] = None, offset: Optional[int] = None, limit: Optional[int] = None,
              auto_continue: bool = True):
        # auto-continue & set limit to max unless the user specified a lower limit, or set auto-continue to False
        if limit is not None:
            auto_continue = False
        if auto_continue:
            limit = 'max'
        data = {}
        fields_to_concat = {
            'tables': tables,
            'fields': fields,
            'join_on': join_on,
            'having': having,
        }
        for field_name, field in fields_to_concat.items():
            if isinstance(field, list):
                data[field_name] = ', '.join(field)
            elif field is not None:
                data[field_name] = field
        fields_to_add = {
            'where': where,
            'group_by': group_by,
            'order_by': order_by,
            'offset': offset,
            'limit': limit,
        }
        for field_name, field in fields_to_add.items():
            if field is not None:
                data[field_name] = field
        ret = []
        while True:
            response = self._make_cargoquery_api_call(data)
            for item in response['cargoquery']:
                for k, v in item['title'].items():
                    if v != '':
                        continue
                    item['title'][k] = None
                ret.append(item['title'])
            if not auto_continue or response['limits']['cargoquery'] > len(response['cargoquery']):
                break
            data['offset'] = len(ret)
        return ret

    def query_one_result(self, fields, **kwargs):
        rows = self.query(fields=fields, **kwargs)
        field = fields.split('=')[1] if '=' in fields else fields
        if len(rows) == 0:
            return None
        row = rows[0]
        if field not in row:
            return None
        return row[field]

    def page_list(self, fields=None, limit="max", page_pattern="%s", **kwargs):
        if isinstance(fields, list):
            fields = ', '.join(fields)
        field = fields.split('=')[1] if '=' in fields else fields
        data = {
            'fields': fields,
            'group_by': fields.split('=')[0],
            'limit': limit,
            **kwargs
        }
        response = self._make_cargoquery_api_call(data)
        pages = []
        for item in response['cargoquery']:
            page = page_pattern % item['title'][field]
            if page in pages:
                continue
            pages.append(page)
            yield self.client.pages[page]

    def create(self, templates):
        self.recreate(templates, replacement=False)

    def recreate(self, templates, replacement=True):
        if isinstance(templates, str):
            templates = [templates]
        token = self.client.get_token('csrf')
        for template in templates:
            if not replacement:
                self.client.api('cargorecreatetables', template=template, token=token)
                continue
            self.client.api('cargorecreatetables', template=template, createReplacement=1, token=token)
