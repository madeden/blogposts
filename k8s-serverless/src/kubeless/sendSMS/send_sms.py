import json
from twilio.rest import Client

# Your Account SID from twilio.com/console
account_sid = "AC38da33d9a8dbc80b0fb114438ed609d5"
# Your Auth Token from twilio.com/console
auth_token  = "281dfa2e3b8734f0627cd133b7af3dcf"

client = Client(account_sid, auth_token)

def handler(context):
    msg = ''.join(['Policy ',context.get('policy', '0000A'),' was ',context.get('status')])

    message = client.messages.create(
        to="+33616702389", 
        from_="+33756799844",
        body=msg)

    print(message.sid)
