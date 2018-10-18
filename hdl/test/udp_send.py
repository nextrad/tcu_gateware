# simple script to send udp packets to REX/passive receivers
# source: https://tutorialedge.net/python/udp-client-server-python/

import socket

# UDP_IP_ADDRESS = '192.168.54.100'
UDP_IP_ADDRESS = '192.168.1.36'
UDP_PORT_NO = 10001

l_band_freq = b'\x14\x05'
x_band_freq = b'\x34\x21'
# TODO: Check if pol needs to be 8/16bits
#       check if pol value matters when changing frequency for either bands for REX
pol = b'\x00'
Message = bytearray(b'\x0d\x00\x00\x00\x00\x00\x04\x00\x03\x00') + l_band_freq + x_band_freq + pol

clientSock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)


def send_message():
    clientSock.sendto(Message, (UDP_IP_ADDRESS, UDP_PORT_NO))
